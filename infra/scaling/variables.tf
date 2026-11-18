variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_profile" {
  type    = string
  default = "study"
}

variable "ami_id" {
  description = "이 리전의 Canonical Ubuntu 24.04 LTS x86_64 AMI ID"
  type        = string
}

variable "instance_type" {
  description = "콘솔에서 프리 티어 표시와 잔여 혜택을 확인한 x86_64 유형"
  type        = string
  default     = "t3.micro"
}

variable "subnet_ids" {
  description = "같은 VPC, 서로 다른 AZ의 퍼블릭 서브넷 2개. IGW 경로도 확인합니다."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) == 2 && length(distinct(var.subnet_ids)) == 2
    error_message = "서로 다른 서브넷 ID 두 개를 입력하세요."
  }
}

variable "desired_count" {
  description = "시연에서 유지할 서버 수. 1대로 시작한 뒤 2대로 변경합니다."
  type        = number
  default     = 1
  validation {
    condition     = contains([1, 2], var.desired_count)
    error_message = "desired_count는 1 또는 2여야 합니다."
  }
}
