# ---------------------------------------------------------------------------
# dev — the architecture from the diagram, in one root module.
#
# Module call order below is for human reading only. Terraform derives the
# real order from references, so anything unreferenced runs in parallel.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# AZ names differ per account (this account's "ap-south-1a" is not necessarily
# the same physical zone as another account's), so they are looked up rather
# than hardcoded.
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Resolve each subnet's az_index into a real AZ name.
  public_subnets = {
    for k, s in var.public_subnets : k => {
      cidr_block        = s.cidr_block
      availability_zone = local.azs[s.az_index]
    }
  }

  private_subnets = {
    for k, s in var.private_subnets : k => {
      cidr_block        = s.cidr_block
      availability_zone = local.azs[s.az_index]
    }
  }

  # S3 bucket names are globally unique across every AWS account on earth.
  # Suffixing the account ID is the standard way to guarantee that.
  app_bucket_name = "${local.name_prefix}-app-${data.aws_caller_identity.current.account_id}"

  # Computed here, not read from the monitoring module's output. The
  # instances' user_data needs this name, and the monitoring module needs the
  # instance IDs — routing the name through the module would be a cycle.
  log_group_name = "/aws/ec2/${local.name_prefix}"

  cloudwatch_namespace = "${var.project_name}/${var.environment}"
}

# ---------------------------------------------------------------------------
# 1. Network — VPC, subnets, IGW, NAT, route tables, S3 endpoint
# ---------------------------------------------------------------------------
module "network" {
  source = "../../modules/network"

  name            = local.name_prefix
  vpc_cidr        = var.vpc_cidr
  public_subnets  = local.public_subnets
  private_subnets = local.private_subnets

  enable_nat_gateway         = var.enable_nat_gateway
  nat_gateway_subnet_key     = var.nat_gateway_subnet_key
  enable_s3_gateway_endpoint = var.enable_s3_gateway_endpoint

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 2. Storage — the application bucket for logs and files
# ---------------------------------------------------------------------------
module "storage" {
  source = "../../modules/storage"

  bucket_name        = local.app_bucket_name
  force_destroy      = var.s3_force_destroy
  log_retention_days = var.s3_log_retention_days

  allow_alb_access_logs = var.alb_enable_access_logs

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 3. IAM — instance role/profile for the servers, plus the admin user
# ---------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  name              = local.name_prefix
  app_bucket_arn    = module.storage.bucket_arn
  create_admin_user = var.create_admin_user

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 4. Load balancer — the only internet-facing entry point
# ---------------------------------------------------------------------------
module "alb" {
  source = "../../modules/alb"

  name       = local.name_prefix
  vpc_id     = module.network.vpc_id
  subnet_ids = [for k in var.alb_subnet_keys : module.network.public_subnet_ids[k]]

  ingress_cidrs     = var.alb_ingress_cidrs
  health_check_path = var.health_check_path

  access_logs_bucket = var.alb_enable_access_logs ? module.storage.bucket_id : null

  tags = var.tags
}

# ---------------------------------------------------------------------------
# 5. Bastion — the SSH entry point, and the only instance with a public IP
# ---------------------------------------------------------------------------
module "bastion" {
  source = "../../modules/ec2"

  name      = "${local.name_prefix}-bastion"
  vpc_id    = module.network.vpc_id
  subnet_id = module.network.public_subnet_ids[var.bastion_subnet_key]

  instance_type    = var.bastion_instance_type
  ami_id           = var.ami_id
  root_volume_size = var.bastion_root_volume_size
  key_name         = var.key_name

  associate_public_ip  = true
  allowed_ssh_cidrs    = var.allowed_ssh_cidrs
  iam_instance_profile = module.iam.instance_profile_name

  user_data = templatefile("${path.module}/user_data/bastion.sh.tftpl", {
    name          = "${local.name_prefix}-bastion"
    region        = var.aws_region
    private_cidrs = join(", ", [for s in var.private_subnets : s.cidr_block])
  })

  tags = merge(var.tags, {
    Role = "bastion"
    Tier = "public"
  })
}

# ---------------------------------------------------------------------------
# 6. Web tier — one instance per private subnet
#
# for_each on the module, so adding a third entry to var.web_servers adds a
# whole instance + security group + rules + alarms, with no other edits.
# ---------------------------------------------------------------------------
module "web" {
  source   = "../../modules/ec2"
  for_each = var.web_servers

  name      = "${local.name_prefix}-${each.key}"
  vpc_id    = module.network.vpc_id
  subnet_id = module.network.private_subnet_ids[each.value.subnet_key]

  instance_type    = var.web_instance_type
  ami_id           = var.ami_id
  root_volume_size = var.web_root_volume_size
  key_name         = var.key_name

  # No public IP: outbound goes through the NAT gateway, inbound only through
  # the load balancer. This is what "private subnet" buys you.
  associate_public_ip  = false
  iam_instance_profile = module.iam.instance_profile_name

  # Both rules reference a source security group rather than a CIDR, so they
  # keep working however the ALB's or bastion's addresses change.
  ingress_rules = {
    http_from_alb = {
      description              = "HTTP from the load balancer"
      from_port                = var.web_port
      to_port                  = var.web_port
      source_security_group_id = module.alb.security_group_id
    }
    ssh_from_bastion = {
      description              = "SSH from the bastion host"
      from_port                = 22
      to_port                  = 22
      source_security_group_id = module.bastion.security_group_id
    }
  }

  user_data = templatefile("${path.module}/user_data/web.sh.tftpl", {
    region               = var.aws_region
    s3_bucket            = module.storage.bucket_id
    log_group_name       = local.log_group_name
    server_name          = "${local.name_prefix}-${each.key}"
    cloudwatch_namespace = local.cloudwatch_namespace
  })

  tags = merge(var.tags, {
    Role = "web"
    Tier = "private"
  })
}

# ---------------------------------------------------------------------------
# 7. Target group registration
#
# Lives here, not inside the alb module, on purpose. The web tier needs the
# ALB's security group ID and the ALB needs the web tier's instance IDs — put
# both directions inside the modules and Terraform rejects the config as a
# cycle. Keeping the attachment at the root breaks it: each module depends on
# the other's *outputs* only, never on the other module.
# ---------------------------------------------------------------------------
resource "aws_lb_target_group_attachment" "web" {
  for_each = module.web

  target_group_arn = module.alb.target_group_arn
  target_id        = each.value.instance_id
  port             = var.web_port
}

# ---------------------------------------------------------------------------
# 8. Monitoring — log group, alarm topic, per-instance and ALB alarms
# ---------------------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  name           = local.name_prefix
  log_group_name = local.log_group_name

  instance_ids = merge(
    { for k, m in module.web : k => m.instance_id },
    { bastion = module.bastion.instance_id },
  )

  log_retention_days = var.cloudwatch_log_retention_days
  cpu_threshold      = var.cpu_alarm_threshold
  alarm_email        = var.alarm_email

  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  tags = var.tags
}
