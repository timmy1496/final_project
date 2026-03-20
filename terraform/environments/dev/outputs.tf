output "ecr_repository_url"    { value = module.ecr.repository_url }
output "eks_cluster_name"      { value = module.eks.cluster_name }
output "eks_cluster_endpoint"  { value = module.eks.cluster_endpoint }
output "rds_endpoint"          { value = module.rds.endpoint }
output "rds_ssm_password_path" { value = module.rds.ssm_password_path }
output "vpc_id"                { value = module.vpc.vpc_id }

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_login_command" {
  value = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.repository_url}"
}
