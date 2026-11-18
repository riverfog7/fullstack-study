terraform {
  required_version = ">= 1.7, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.32.1, < 7.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}
