variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
