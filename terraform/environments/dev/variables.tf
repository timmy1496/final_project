variable "aws_region"   { type = string default = "eu-central-1" }
variable "environment"  { type = string default = "dev" }
variable "project_name" { type = string default = "go-app" }

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "kubernetes_version"  { type = string default = "1.29" }
variable "node_instance_types" { type = list(string) default = ["t3.medium"] }
variable "node_desired_size"   { type = number default = 2 }
variable "node_min_size"       { type = number default = 1 }
variable "node_max_size"       { type = number default = 4 }
variable "ec2_ssh_key_name"    { type = string default = "" }

variable "rds_instance_class"  { type = string default = "db.t3.micro" }
variable "db_name"             { type = string default = "appdb" }

variable "common_tags" {
  type = map(string)
  default = {
    Project     = "go-app"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
