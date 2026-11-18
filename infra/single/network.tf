# 이미 있는 퍼블릭 서브넷을 조회하고 같은 VPC에 보안 그룹을 만듭니다.
data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_security_group" "app" {
  name_prefix = "study-app-"
  description = "SSH and study app"
  vpc_id      = data.aws_subnet.selected.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidrs
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.web_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
