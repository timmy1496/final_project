variable "project_name"               { type = string }
variable "vpc_id"                      { type = string }
variable "vpc_cidr"                    { type = string }
variable "public_subnet_ids"           { type = list(string) }
variable "private_subnet_ids"          { type = list(string) }
variable "kubernetes_version"          { type = string default = "1.29" }
variable "cluster_public_access_cidrs" { type = list(string) default = ["0.0.0.0/0"] }
variable "node_instance_types"         { type = list(string) default = ["t3.medium"] }
variable "node_disk_size"              { type = number default = 20 }
variable "node_desired_size"           { type = number default = 2 }
variable "node_min_size"               { type = number default = 1 }
variable "node_max_size"               { type = number default = 4 }
variable "ec2_ssh_key_name"            { type = string default = "" }
variable "common_tags"                 { type = map(string) default = {} }
