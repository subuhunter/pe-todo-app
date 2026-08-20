variable "name" {
  description = "Name prefix for resources created by this module."
  type        = string
}

variable "vpc_id" {
  description = "VPC the instance and its security group live in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance into."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI to launch. Leave null to use the latest Amazon Linux 2023."
  type        = string
  default     = null
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 20
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH, or null."
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed on port 22. Empty list means no SSH rule is created."
  type        = list(string)
  default     = []
}

variable "associate_public_ip" {
  description = "Whether to assign a public IP."
  type        = bool
  default     = false
}

variable "user_data" {
  description = "Cloud-init / shell script to run on first boot."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags for the instance."
  type        = map(string)
  default     = {}
}

variable "ingress_rules" {
  description = <<-EOT
    Ingress rules keyed by a stable name. Exactly one of cidr_ipv4 or
    source_security_group_id must be set per rule.

    Referencing a source security group instead of a CIDR is what keeps the
    web tier reachable only through the load balancer and the bastion — the
    rule follows those resources wherever their IPs move.

    The key becomes the resource address, so renaming a key destroys and
    recreates that rule.
  EOT
  type = map(object({
    from_port                = number
    to_port                  = number
    ip_protocol              = optional(string, "tcp")
    description              = optional(string)
    cidr_ipv4                = optional(string)
    source_security_group_id = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, r in var.ingress_rules :
      (r.cidr_ipv4 == null) != (r.source_security_group_id == null)
    ])
    error_message = "Each ingress rule must set exactly one of cidr_ipv4 or source_security_group_id."
  }
}

variable "iam_instance_profile" {
  description = <<-EOT
    Name of an IAM instance profile to attach. This is how the instance gets
    short-lived AWS credentials for S3, CloudWatch and SSM without any key
    material on disk. Null attaches none.
  EOT
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = <<-EOT
    Replace the instance when user_data changes. user_data only runs on first
    boot, so with this false an edited script has no effect until you
    terminate the instance yourself.
  EOT
  type        = bool
  default     = false
}
