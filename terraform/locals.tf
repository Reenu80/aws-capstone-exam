locals {
  project = "aws-capstone-exam"

  # Fixed CIDRs by requirement
  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidr_a  = "10.0.1.0/24"
  public_subnet_cidr_b  = "10.0.2.0/24"
  private_subnet_cidr_a = "10.0.3.0/24"
  private_subnet_cidr_b = "10.0.4.0/24"

  tags = {
    Project = local.project
    Owner   = "Harshini"
  }
}
