variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks (2 subnets across 2 AZs)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks (2 subnets across 2 AZs)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}


variable "my_ip" {
  description = "Your laptop public IP in CIDR format for SSH access (x.x.x.x/32)"
  type        = string
}


variable "key_name" {
  description = "Existing EC2 Key Pair name in AWS"
  type        = string
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "streamline"
}

variable "db_user" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "db_pass" {
  description = "RDS master password (exam only; use Secrets Manager in real projects)"
  type        = string
  default     = "Admin12345!"
  sensitive   = true
}
