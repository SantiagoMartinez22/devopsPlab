terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Groups
resource "aws_security_group" "ec2" {
  name        = "todo-app-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "todo-app-ec2-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "todo-app-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  tags = {
    Name = "todo-app-rds-sg"
  }
}

# EC2 Instance
resource "aws_instance" "app" {
  ami           = var.ec2_ami
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name              = var.key_name

  tags = {
    Name = "todo-app-server"
  }
}

# RDS Instance
resource "aws_db_instance" "postgres" {
  identifier           = "todo-app-db"
  allocated_storage    = 20
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "14"
  instance_class      = "db.t3.micro"
  db_name             = var.db_name
  username            = var.db_username
  password            = var.db_password
  skip_final_snapshot = true
  
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = {
    Name = "todo-app-db"
  }
} 