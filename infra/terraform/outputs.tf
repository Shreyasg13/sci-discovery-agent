output "app_public_ip" {
  description = "Public IP of the app EC2 instance"
  value       = aws_instance.app.public_ip
}

output "research_public_ip" {
  description = "Public IP of the research EC2 instance"
  value       = aws_instance.research.public_ip
}

output "data_bucket_name" {
  description = "S3 data bucket name"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "db_endpoint" {
  description = "RDS Postgres endpoint"
  value       = aws_db_instance.postgres.address
}

output "db_master_username" {
  value       = aws_db_instance.postgres.username
  description = "RDS master username"
}

output "db_master_password" {
  value       = random_password.db_master.result
  description = "RDS master password"
  sensitive   = true
}
