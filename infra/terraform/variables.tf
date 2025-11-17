variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "project_prefix" {
  description = "Prefix for tagging and naming resources"
  type        = string
  default     = "sci-discovery-agent"
}

variable "key_name" {
  description = "Name of existing EC2 key pair in AWS"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your IP address in CIDR notation for SSH (e.g., 1.2.3.4/32)"
  type        = string
}

variable "db_master_password" {
  description = "Master password for RDS Postgres (must satisfy AWS RDS rules)"
  type        = string
  sensitive   = true
}
