variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_profile" {
  description = "aws login으로 로그인한 AWS CLI 프로필 이름"
  type        = string
  default     = "study"
}

variable "ami_id" {
  description = "선택한 리전의 Canonical Ubuntu 24.04 LTS x86_64 AMI ID"
  type        = string
}

variable "instance_type" {
  description = "콘솔에서 프리 티어 사용 가능 표시를 확인한 x86_64 유형"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "이 리전에 먼저 만들어 둔 키 페어 이름. 개인키 내용은 입력하지 않습니다."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", var.key_name))
    error_message = "키 이름에는 영문, 숫자, 밑줄, 점, 하이픈을 사용합니다."
  }
}

variable "subnet_id" {
  description = "선택한 리전에 이미 있는 퍼블릭 서브넷 ID"
  type        = string
}

variable "ssh_cidrs" {
  description = "SSH 접속을 허용할 IPv4 CIDR 목록. 평소에는 내 공인 IP/32를 사용합니다."
  type        = list(string)
  validation {
    condition     = length(var.ssh_cidrs) > 0 && alltrue([for cidr in var.ssh_cidrs : can(cidrnetmask(cidr))])
    error_message = "203.0.113.10/32처럼 IPv4 CIDR을 하나 이상 입력하세요."
  }
}

variable "web_cidrs" {
  description = "웹 앱의 8080 포트 접속을 허용할 IPv4 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  validation {
    condition     = length(var.web_cidrs) > 0 && alltrue([for cidr in var.web_cidrs : can(cidrnetmask(cidr))])
    error_message = "IPv4 CIDR을 하나 이상 입력하세요."
  }
}

variable "repo_url" {
  description = "EC2가 clone할 공개 GitHub 저장소의 HTTPS 주소"
  type        = string
  default     = "https://github.com/riverfog7/fullstack-study.git"
  validation {
    condition     = can(regex("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.repo_url))
    error_message = "토큰이나 명령을 넣지 말고 공개 GitHub HTTPS 주소를 입력하세요."
  }
}

variable "repo_ref" {
  description = "clone한 저장소에서 사용할 Git 커밋 SHA(7~40자리, 전체 SHA 권장)"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{7,40}$", var.repo_ref))
    error_message = "이미 push한 Git 커밋의 SHA를 입력하세요(7~40자리)."
  }
}

variable "dockerhub_username" {
  description = "study-backend와 study-frontend 공개 이미지가 있는 Docker Hub 계정명"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]*$", var.dockerhub_username))
    error_message = "Docker Hub 계정명만 입력하세요. 비밀번호나 PAT는 넣지 않습니다."
  }
}

variable "image_tag" {
  description = "두 이미지에 이미 게시된 동일한 태그. 예: week4-demo 또는 커밋 SHA"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.image_tag))
    error_message = "영문, 숫자, 밑줄, 점, 하이픈으로 된 이미지 태그를 입력하세요."
  }
}
