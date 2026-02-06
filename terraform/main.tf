terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Pick 2 AZs automatically in us-east-1
data "aws_availability_zones" "az" {
  state = "available"
}

# Latest Amazon Linux 2 AMI
data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

############################
# NETWORKING
############################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "streamline-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "streamline-igw" }
}

# Public subnets (2 AZs)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.az.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "streamline-public-${count.index + 1}" }
}

# Private subnets (2 AZs)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.az.names[count.index]

  tags = { Name = "streamline-private-${count.index + 1}" }
}

# Public route table -> IGW
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "streamline-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private route table (no NAT required for this exam)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "streamline-private-rt" }
}

resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

############################
# SECURITY GROUPS
############################
# Web SG: HTTP from anywhere + SSH from YOUR public IP
resource "aws_security_group" "web_sg" {
  name        = "streamline-web-sg"
  description = "Web tier SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "streamline-web-sg" }
}

# RDS SG: MySQL only from web SG
resource "aws_security_group" "rds_sg" {
  name        = "streamline-rds-sg"
  description = "RDS tier SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from Web SG only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "streamline-rds-sg" }
}

############################
# COMPUTE (2 EC2)
############################
resource "aws_instance" "web" {
  count                  = 2
  ami                    = data.aws_ami.amzn2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = 	streamline.key

  user_data = file("${path.module}/userdata.sh")

  tags = {
    Name = "streamline-web-${count.index + 1}"
  }
}

############################
# LOAD BALANCER (ALB)
############################
resource "aws_lb" "alb" {
  name               = "streamline-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.web_sg.id]
  subnets         = [aws_subnet.public[0].id, aws_subnet.public[1].id]

  tags = { Name = "streamline-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "streamline-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

############################
# DATABASE (RDS MySQL)
############################
resource "aws_db_subnet_group" "db_subnets" {
  name       = "streamline-db-subnets"
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  tags       = { Name = "streamline-db-subnets" }
}

resource "aws_db_instance" "mysql" {
  identifier            = "streamline-mysql"
  allocated_storage     = 20
  engine                = "mysql"
  engine_version        = "8.0"
  instance_class        = "db.t3.micro"

  db_name  = var.db_name
  username = var.db_user
  password = var.db_pass

  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible   = false
  skip_final_snapshot   = true
  deletion_protection   = false
}
