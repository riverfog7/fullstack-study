data "aws_subnet" "selected" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

data "aws_ami" "ubuntu" {
  owners = ["099720109477"] # Canonical
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  vpc_id = data.aws_subnet.selected[var.subnet_ids[0]].vpc_id
}

# 인터넷의 웹 요청은 ALB만 받습니다.
resource "aws_security_group" "alb" {
  name_prefix = "study-alb-"
  description = "Public HTTP for the scaling demo"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2의 8080은 ALB 보안 그룹에서 오는 요청만 받습니다.
resource "aws_security_group" "app" {
  name_prefix = "study-scaling-"
  description = "HTTP from the ALB only"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app" {
  name_prefix        = "study-"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  lifecycle {
    precondition {
      condition     = length(toset([for subnet in data.aws_subnet.selected : subnet.vpc_id])) == 1
      error_message = "두 서브넷은 같은 VPC에 있어야 합니다."
    }
    precondition {
      condition     = length(toset([for subnet in data.aws_subnet.selected : subnet.availability_zone])) == 2
      error_message = "두 서브넷은 서로 다른 가용 영역(AZ)에 있어야 합니다."
    }
  }
}

resource "aws_lb_target_group" "app" {
  name_prefix          = "study-"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = local.vpc_id
  deregistration_delay = 10

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "study-scaling-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  user_data     = filebase64("${path.module}/demo-bootstrap.sh")

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.app.id]
  }
  block_device_mappings {
    device_name = data.aws_ami.ubuntu.root_device_name
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  metadata_options {
    http_tokens = "required"
  }
  dynamic "credit_specification" {
    for_each = can(regex("^t[23]", var.instance_type)) ? [1] : []
    content {
      cpu_credits = "standard"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name_prefix               = "study-scaling-"
  min_size                  = 1
  desired_capacity          = var.desired_count
  max_size                  = 2
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 300
  wait_for_elb_capacity     = var.desired_count

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }
  target_group_arns = [aws_lb_target_group.app.arn]

  tag {
    key                 = "Name"
    value               = "study-scaling-demo"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]
}
