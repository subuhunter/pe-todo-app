variable "name" {
  description = "Name prefix for every resource in this module."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = <<-EOT
    Public subnets, keyed by a stable name. The key becomes part of the Name
    tag and is how callers look the subnet up in the output map, so renaming a
    key destroys and recreates that subnet.
  EOT
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "private_subnets" {
  description = "Private subnets, keyed by a stable name. Same key rules as public_subnets."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Create a NAT Gateway so private subnets can reach the internet. Setting
    this to false leaves the private subnets with no default route: package
    installs and CloudWatch log delivery from private instances will fail,
    though S3 still works if enable_s3_gateway_endpoint is true.
  EOT
  type        = bool
  default     = true
}

variable "nat_gateway_subnet_key" {
  description = "Which key in public_subnets holds the NAT Gateway. Must be a public subnet."
  type        = string
  default     = "public-a"
}

variable "enable_s3_gateway_endpoint" {
  description = "Create an S3 gateway VPC endpoint. Free, and keeps S3 traffic off the NAT Gateway."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto every resource in this module."
  type        = map(string)
  default     = {}
}
