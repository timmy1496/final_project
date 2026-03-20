output "endpoint"          { value = aws_db_instance.main.endpoint }
output "port"              { value = aws_db_instance.main.port }
output "database_name"     { value = aws_db_instance.main.db_name }
output "username"          { value = aws_db_instance.main.username }
output "security_group_id" { value = aws_security_group.rds.id }
output "ssm_password_path" { value = aws_ssm_parameter.db_password.name }
output "ssm_endpoint_path" { value = aws_ssm_parameter.db_endpoint.name }
