# 먼저 만든 키 페어를 조회합니다. 개인키를 만들거나 저장하지 않습니다.
data "aws_key_pair" "study" {
  key_name = var.key_name
}

# AMI를 자동 갱신하지 않고, 입력한 이미지의 배포자·OS·아키텍처를 확인합니다.
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

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true
  key_name                    = data.aws_key_pair.study.key_name

  user_data = templatefile("${path.module}/bootstrap.sh.tftpl", {
    repo_url           = var.repo_url
    repo_ref           = var.repo_ref
    dockerhub_username = var.dockerhub_username
    image_tag          = var.image_tag
  })
  user_data_replace_on_change = true # 초기 설치 내용 변경 시 EC2를 다시 만듭니다.

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
  metadata_options {
    http_tokens = "required"
  }
  # T2/T3/T3a는 추가 CPU 크레딧 과금을 피하도록 standard를 사용합니다.
  dynamic "credit_specification" {
    for_each = can(regex("^t[23]", var.instance_type)) ? [1] : []
    content {
      cpu_credits = "standard"
    }
  }
  tags = {
    Name = "study-app-terraform"
  }
}
