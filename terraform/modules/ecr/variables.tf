variable "repository_name"    { type = string }
variable "max_image_count"    { type = number; default = 10 }
variable "push_principal_arns" { type = list(string); default = [] }
variable "common_tags"        { type = map(string); default = {} }
