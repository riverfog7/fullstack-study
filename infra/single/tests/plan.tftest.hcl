# mock provider를 사용하므로 AWS에 접속하거나 리소스를 만들지 않습니다.
mock_provider "aws" {
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-00000000000000001" }
  }
  mock_data "aws_ami" {
    defaults = { id = "ami-0123456789abcdef0" }
  }
  mock_data "aws_key_pair" {
    defaults = { key_name = "study-key" }
  }
  mock_resource "aws_instance" {
    defaults = {
      id        = "i-00000000000000001"
      public_ip = "203.0.113.20"
    }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-00000000000000001" }
  }
}

variables {
  ami_id             = "ami-0123456789abcdef0"
  key_name           = "study-key"
  subnet_id          = "subnet-00000000000000001"
  ssh_cidrs          = ["203.0.113.10/32"]
  repo_ref           = "328eed567b4c7a5b80ad0896ab915162fe0cab8b"
  dockerhub_username = "studyexample"
  image_tag          = "week4-demo"
}

run "single_ec2_plan" {
  command = plan

  assert {
    condition = (
      aws_instance.app.key_name == "study-key" &&
      aws_instance.app.metadata_options[0].http_tokens == "required" &&
      aws_instance.app.credit_specification[0].cpu_credits == "standard"
    )
    error_message = "기존 키, IMDSv2, standard CPU credits가 설정되어야 합니다."
  }
  assert {
    condition = (
      aws_instance.app.root_block_device[0].volume_size == 8 &&
      aws_instance.app.root_block_device[0].encrypted &&
      aws_instance.app.root_block_device[0].delete_on_termination
    )
    error_message = "실습용 루트 디스크는 암호화한 8GiB이며 인스턴스 종료 시 삭제해야 합니다."
  }
  assert {
    condition = (
      length(aws_security_group.app.ingress) == 2 &&
      alltrue([for rule in aws_security_group.app.ingress :
        rule.from_port == 22 ? toset(rule.cidr_blocks) == toset(var.ssh_cidrs) : rule.from_port == 8080
      ])
    )
    error_message = "외부 포트는 SSH와 8080이며 SSH는 입력한 CIDR로 제한해야 합니다."
  }
}

run "reject_ipv6_ssh_cidr" {
  command = plan
  variables {
    ssh_cidrs = ["::/0"]
  }
  expect_failures = [var.ssh_cidrs]
}

run "reject_repository_command" {
  command = plan
  variables {
    repo_url = "https://github.com/owner/repo.git'; touch /tmp/unexpected; #"
  }
  expect_failures = [var.repo_url]
}

run "reject_image_env_injection" {
  command = plan
  variables {
    image_tag = "week4-demo\nUNEXPECTED=value"
  }
  expect_failures = [var.image_tag]
}

# 아래 apply는 mock provider의 가상 state만 만듭니다. 실제 AWS 호출은 없습니다.
run "mock_initial_state" {
  command = apply
}

run "web_cidrs_update_without_instance_replacement" {
  command = plan
  variables {
    web_cidrs = ["198.51.100.20/32"]
  }
  assert {
    condition = (
      aws_instance.app.id == run.mock_initial_state.instance_id &&
      aws_security_group.app.id == run.mock_initial_state.security_group_id
    )
    error_message = "웹 접속 CIDR만 바꿀 때 EC2와 보안 그룹을 교체하면 안 됩니다."
  }
  assert {
    condition     = one([for rule in aws_security_group.app.ingress : toset(rule.cidr_blocks) if rule.from_port == 8080]) == toset(var.web_cidrs)
    error_message = "8080 인바운드 규칙에 변경한 web_cidrs를 적용해야 합니다."
  }
}
