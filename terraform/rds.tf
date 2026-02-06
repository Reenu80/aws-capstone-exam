# Get the latest Amazon Linux 2 AMI via SSM Parameter (stable across regions)
data "aws_ssm_parameter" "amzn2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# User data: install Apache/PHP, clone repo, checkout branch, copy index.php
locals {
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd php git
    systemctl enable httpd
    systemctl start httpd

    cd /var/www/html
    if [ ! -d "app" ]; then
      git clone ${var.git_repo_url} app
    fi

    cd app
    git fetch --all
    git checkout ${var.deploy_branch}
    git pull origin ${var.deploy_branch}

    cp -f index.php /var/www/html/index.php
    chown -R apache:apache /var/www/html
    systemctl restart httpd
  EOF
}

# Two EC2 instances in two public subnets
resource "aws_instance" "web_a" {
  ami                         = data.aws_ssm_parameter.amzn2_ami.value
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = merge(local.tags, { Name = "${local.project}-web-a" })
}

resource "aws_instance" "web_b" {
  ami                         = data.aws_ssm_parameter.amzn2_ami.value
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public_b.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  user_data                   = local.user_data

  tags = merge(local.tags, { Name = "${local.project}-web-b" })
}

# Target Group for EC2 instances
resource "aws_lb_target_group" "tg" {
  name        = "${local.project}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.tags, { Name = "${local.project}-tg" })
}

# Application Load Balancer in public subnets
resource "aws_lb" "alb" {
  name               = "${local.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = merge(local.tags, { Name = "${local.project}-alb" })
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

resource "aws_lb_target_group_attachment" "attach_a" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach_b" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web_b.id
  port             = 80
}
