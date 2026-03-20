variable "project_name"              { type = string }
variable "vpc_id"                     { type = string }
variable "private_subnet_ids"         { type = list(string) }
variable "allowed_security_group_ids" { type = list(string); default = [] }
variable "allowed_cidr_blocks"        { type = list(string); default = [] }
variable "mysql_version"              { type = string; default = "8.0" }
variable "instance_class"             { type = string; default = "db.t3.micro" }
variable "allocated_storage"          { type = number; default = 20 }
variable "max_allocated_storage"      { type = number; default = 100 }
variable "database_name"              { type = string; default = "appdb" }
variable "master_username"            { type = string; default = "admin" }
variable "backup_retention_days"      { type = number; default = 7 }
variable "deletion_protection"        { type = bool; default = true }
variable "multi_az"                   { type = bool; default = false }
variable "common_tags"                { type = map(string); default = {} }
