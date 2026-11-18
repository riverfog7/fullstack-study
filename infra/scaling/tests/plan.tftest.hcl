# 실제 AWS 인증·생성 없이 구성과 입력 조건을 검사합니다.
mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id               = "ami-0123456789abcdef0"
      root_device_name = "/dev/sda1"
    }
  }
}

override_data {
  target = data.aws_subnet.selected["subnet-00000000000000001"]
  values = {
    vpc_id            = "vpc-00000000000000001"
    availability_zone = "ap-northeast-2a"
  }
}

override_data {
  target = data.aws_subnet.selected["subnet-00000000000000002"]
  values = {
    vpc_id            = "vpc-00000000000000001"
    availability_zone = "ap-northeast-2b"
  }
}

variables {
  ami_id     = "ami-0123456789abcdef0"
  subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
}

run "public_alb_private_app_ingress" {
  command = plan

  assert {
    condition = (
      one(aws_security_group.alb.ingress).from_port == 80 &&
      one(aws_security_group.alb.ingress).to_port == 80 &&
      toset(one(aws_security_group.alb.ingress).cidr_blocks) == toset(["0.0.0.0/0"])
    )
    error_message = "인터넷의 웹 요청은 ALB의 80번 포트로 받아야 합니다."
  }
  assert {
    condition = (
      length(aws_security_group.app.ingress) == 1 &&
      one(aws_security_group.app.ingress).from_port == 8080 &&
      one(aws_security_group.app.ingress).to_port == 8080 &&
      length(one(aws_security_group.app.ingress).cidr_blocks) == 0 &&
      length(one(aws_security_group.app.ingress).ipv6_cidr_blocks) == 0 &&
      length(one(aws_security_group.app.ingress).security_groups) == 1
    )
    error_message = "EC2는 8080에서 ALB 보안 그룹의 요청만 받아야 합니다. SSH나 직접 인터넷 접속은 열지 않습니다."
  }
  assert {
    condition = (
      aws_autoscaling_group.app.health_check_type == "ELB" &&
      aws_lb_target_group.app.health_check[0].path == "/" &&
      aws_lb_target_group.app.health_check[0].matcher == "200"
    )
    error_message = "ASG가 ALB의 HTTP 상태 검사를 사용해야 합니다."
  }
}

run "scale_to_two" {
  command = plan
  variables {
    desired_count = 2
  }
  assert {
    condition = (
      aws_autoscaling_group.app.desired_capacity == 2 &&
      aws_autoscaling_group.app.min_size == 1 &&
      aws_autoscaling_group.app.max_size == 2
    )
    error_message = "선택 시연은 최대 두 대 범위 안에서 희망 용량을 바꿉니다."
  }
}

run "reject_same_az" {
  command = plan
  override_data {
    target = data.aws_subnet.selected["subnet-00000000000000002"]
    values = {
      vpc_id            = "vpc-00000000000000001"
      availability_zone = "ap-northeast-2a"
    }
  }
  expect_failures = [aws_lb.app]
}

run "reject_different_vpc" {
  command = plan
  override_data {
    target = data.aws_subnet.selected["subnet-00000000000000002"]
    values = {
      vpc_id            = "vpc-00000000000000002"
      availability_zone = "ap-northeast-2b"
    }
  }
  expect_failures = [aws_lb.app]
}

run "reject_more_than_two" {
  command = plan
  variables {
    desired_count = 3
  }
  expect_failures = [var.desired_count]
}
