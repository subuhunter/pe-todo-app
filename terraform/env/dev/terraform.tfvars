# Dev environment values. Committed on purpose — no secrets belong in here.

aws_region   = "ap-south-1"
project_name = "platform-demo"
environment  = "dev"

# Refuses to apply against any other AWS account. Set to [] to disable.
allowed_account_ids = ["354389687178"]

# --- Network -----------------------------------------------------------
# Subnet layout matches the architecture diagram. az_index picks from the
# account's availability zone list, so 0 and 1 are two different zones.
vpc_cidr = "10.0.0.0/16"
az_count = 2

public_subnets = {
  "public-a" = { cidr_block = "10.0.1.0/24", az_index = 0 }
  "public-b" = { cidr_block = "10.0.2.0/24", az_index = 1 }
  "bastion"  = { cidr_block = "10.0.3.0/24", az_index = 0 }
}

private_subnets = {
  "private-a" = { cidr_block = "10.0.11.0/24", az_index = 0 }
  "private-b" = { cidr_block = "10.0.12.0/24", az_index = 1 }
}

# The NAT gateway is ~$32/month and is the bulk of this stack's cost.
# Set to false when you are not actively using the environment.
enable_nat_gateway         = true
enable_s3_gateway_endpoint = true

# --- Compute -----------------------------------------------------------
web_servers = {
  "web-1" = { subnet_key = "private-a" }
  "web-2" = { subnet_key = "private-b" }
}

web_instance_type     = "t3.micro"
web_root_volume_size  = 20
bastion_instance_type = "t3.micro"

# Existing key pair name. Leave commented out to launch without SSH keys and
# reach the instances through SSM Session Manager instead.
# key_name = "my-keypair"

# Bastion SSH ingress. Your own address as a /32 — 0.0.0.0/0 is rejected.
# allowed_ssh_cidrs = ["203.0.113.10/32"]

# Pin this before you care about uptime; null tracks the newest AL2023 and a
# new release will plan an instance replacement.
# ami_id = "ami-0123456789abcdef0"

# --- Load balancer -----------------------------------------------------
alb_ingress_cidrs = ["0.0.0.0/0"]
health_check_path = "/health"

# --- Storage -----------------------------------------------------------
s3_force_destroy      = true
s3_log_retention_days = 30

# --- Monitoring --------------------------------------------------------
cloudwatch_log_retention_days = 14
cpu_alarm_threshold           = 80

# Subscribe an address to the alarm topic. You must click the confirmation
# link AWS emails before anything is delivered.
# alarm_email = "you@example.com"

tags = {
  Owner = "platform-team"
}
