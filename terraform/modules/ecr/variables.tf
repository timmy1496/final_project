variable "repository_name" {
  description = "ECR repository name"
  type        = string
}

variable "max_image_count" {
  description = "Max number of tagged images to keep"
  type        = number
  default     = 10
}

variable "push_principal_arns" {
  description = "IAM ARNs allowed to push images"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
