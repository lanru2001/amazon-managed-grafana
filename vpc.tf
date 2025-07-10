variable "environment" {
  description = "Deployment environment identifier"
  type        = string
}

variable "vpc_private_subnets" {
  description = "The private subnets for the VPC"
  type        = list(string)
}

variable "vpc_private_subnets_cidr_blocks" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
}
