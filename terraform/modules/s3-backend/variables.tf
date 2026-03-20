variable "bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
