terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

########################
# Data: Ubuntu AMI
########################

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

########################
# Security Group
########################

resource "aws_security_group" "sci_agent_sg" {
  name        = "${var.project_prefix}-sg"
  description = "Security group for Scientific Discovery Agent"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from my IP (adjust in Terraform if needed)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP for API/UI"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_prefix}-sg"
    Project = var.project_prefix
  }
}

data "aws_vpc" "default" {
  default = true
}

########################
# EC2: App Node
########################

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.sci_agent_sg.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }

  tags = {
    Name    = "${var.project_prefix}-app"
    Role    = "app"
    Project = var.project_prefix
  }
}

########################
# EC2: Research Node
########################

resource "aws_instance" "research" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "c7i.large"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.sci_agent_sg.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 100
  }

  tags = {
    Name    = "${var.project_prefix}-research"
    Role    = "research"
    Project = var.project_prefix
  }
}

########################
# S3 Bucket
########################

resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.project_prefix}-data-${random_id.bucket_suffix.hex}"

  tags = {
    Name    = "${var.project_prefix}-data"
    Project = var.project_prefix
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

########################
# RDS Postgres
########################



resource "aws_db_subnet_group" "default" {
  name       = "${var.project_prefix}-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name    = "${var.project_prefix}-db-subnet-group"
    Project = var.project_prefix
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_prefix}-rds-sg"
  description = "RDS security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Postgres from app and research nodes"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.sci_agent_sg.id
    ]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_prefix}-rds-sg"
    Project = var.project_prefix
  }
}

resource "aws_db_instance" "postgres" {
  identifier        = "${var.project_prefix}-db"
  engine            = "postgres"
  instance_class    = "db.t3.medium"
  allocated_storage = 100

  db_name  = "scidb"
  username = "sci_admin"
  password = var.db_master_password   

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true

  publicly_accessible = false
  storage_encrypted   = true

  tags = {
    Name    = "${var.project_prefix}-postgres"
    Project = var.project_prefix
  }
}

