# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "allowed_account_ids" {
  description = <<-EOT
    AWS account IDs this stack is permitted to apply to. Any other account
    fails at provider configuration, before a single resource is touched.
    An empty list disables the check.

    This is not a secret: the account ID already appears in backend.tf as part
    of the state bucket name, and account IDs are not credentials.
  EOT
  type        = list(string)
  default     = ["354389687178"]
}

variable "project_name" {
  description = "Short name used to prefix resource names."
  type        = string
  default     = "platform-demo"
}

variable "environment" {
  description = "Deployment environment. Pinned to dev in this stack."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This stack is the dev environment; use env/qa or env/production instead."
  }
}

variable "tags" {
  description = "Extra tags merged onto resources, on top of the provider's default_tags."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "How many availability zones to spread across. az_index values below must be less than this."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "At least two AZs are required — an Application Load Balancer will not launch in one."
  }
}

variable "public_subnets" {
  description = <<-EOT
    Public subnets, keyed by name. az_index selects from the AZ list, so
    az_index = 0 and az_index = 1 land in different zones.
  EOT
  type = map(object({
    cidr_block = string
    az_index   = number
  }))
  default = {
    "public-a" = { cidr_block = "10.0.1.0/24", az_index = 0 }
    "public-b" = { cidr_block = "10.0.2.0/24", az_index = 1 }
    "bastion"  = { cidr_block = "10.0.3.0/24", az_index = 0 }
  }
}

variable "private_subnets" {
  description = "Private subnets, keyed by name. Same az_index rules as public_subnets."
  type = map(object({
    cidr_block = string
    az_index   = number
  }))
  default = {
    "private-a" = { cidr_block = "10.0.11.0/24", az_index = 0 }
    "private-b" = { cidr_block = "10.0.12.0/24", az_index = 1 }
  }
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Create a NAT gateway for the private subnets. This is the single most
    expensive resource in the stack (~$32/month plus data processing).
    Turning it off saves that money but breaks package installs and
    CloudWatch log delivery on the web tier.
  EOT
  type        = bool
  default     = true
}

variable "nat_gateway_subnet_key" {
  description = "Which public subnet holds the NAT gateway."
  type        = string
  default     = "public-a"
}

variable "enable_s3_gateway_endpoint" {
  description = "Create an S3 gateway VPC endpoint. Free, and keeps S3 traffic off the NAT gateway."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------

variable "web_servers" {
  description = <<-EOT
    Web servers, keyed by name. Each key becomes one EC2 instance with its own
    security group and alarms. subnet_key must exist in private_subnets.
  EOT
  type = map(object({
    subnet_key = string
  }))
  default = {
    "web-1" = { subnet_key = "private-a" }
    "web-2" = { subnet_key = "private-b" }
  }
}

variable "web_instance_type" {
  description = "Instance type for the web servers."
  type        = string
  default     = "t3.micro"
}

variable "web_root_volume_size" {
  description = "Root volume size in GiB for the web servers."
  type        = number
  default     = 20
}

variable "web_port" {
  description = "Port the web servers listen on and the ALB forwards to."
  type        = number
  default     = 80
}

variable "bastion_subnet_key" {
  description = "Which public subnet the bastion launches into."
  type        = string
  default     = "bastion"
}

variable "bastion_instance_type" {
  description = "Instance type for the bastion host."
  type        = string
  default     = "t3.micro"
}

variable "bastion_root_volume_size" {
  description = "Root volume size in GiB for the bastion host."
  type        = number
  default     = 8
}

variable "ami_id" {
  description = <<-EOT
    AMI for every instance. Null looks up the latest Amazon Linux 2023, which
    means a new AL2023 release will show up as an instance replacement in a
    later plan. Pin this before you care about uptime.
  EOT
  type        = string
  default     = null
}

variable "key_name" {
  description = <<-EOT
    Existing EC2 key pair name for SSH. Null launches without one, in which
    case the only way in is SSM Session Manager — which works, because every
    instance carries the SSM policy.
  EOT
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = <<-EOT
    CIDR blocks allowed to SSH to the BASTION. Empty means no SSH ingress at
    all. The web servers never take SSH from a CIDR — only from the bastion's
    security group.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "Refusing to open SSH to the entire internet. Use your own address as a /32."
  }
}

# ---------------------------------------------------------------------------
# Load balancer
# ---------------------------------------------------------------------------

variable "alb_subnet_keys" {
  description = "Which public subnets host the ALB nodes. Must be at least two, in different AZs."
  type        = list(string)
  default     = ["public-a", "public-b"]
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the load balancer. 0.0.0.0/0 is correct for a public website."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "health_check_path" {
  description = "Path the ALB requests to decide whether a target is healthy. The web user_data creates this file."
  type        = string
  default     = "/health"
}

variable "alb_enable_access_logs" {
  description = <<-EOT
    Write ALB access logs to the application bucket. Off by default because
    the bucket policy has to name the regional ELB log-delivery account, and
    that account only exists for regions launched before August 2022.
  EOT
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

variable "s3_force_destroy" {
  description = "Let terraform destroy delete the application bucket even when it still holds objects."
  type        = bool
  default     = true
}

variable "s3_log_retention_days" {
  description = "Days to keep objects under the logs/ prefix in the application bucket."
  type        = number
  default     = 30
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

variable "create_admin_user" {
  description = "Create the admin IAM user from the architecture diagram. No access key is generated."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Monitoring
# ---------------------------------------------------------------------------

variable "cloudwatch_log_retention_days" {
  description = "Days to retain CloudWatch log events."
  type        = number
  default     = 14
}

variable "cpu_alarm_threshold" {
  description = "CPU percentage above which the high-CPU alarm fires."
  type        = number
  default     = 80
}

variable "alarm_email" {
  description = "Email address subscribed to the alarm topic. The recipient must click the confirmation link before anything is delivered."
  type        = string
  default     = null
}
