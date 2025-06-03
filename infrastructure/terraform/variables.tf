variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instance"
  type        = string
  # Amazon Linux 2 AMI ID for us-east-1
  default     = "ami-06c8f2ec674c67112"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "tododb"
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
} 