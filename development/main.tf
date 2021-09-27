terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.44.0"
    }
  }

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "chhyun"

    workspaces {
      name = "development-chhyun"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

data "terraform_remote_state" "vpc" {
  backend = "remote"
  config = {
    organization = "chhyun"

    workspaces = {
      name = "vpc"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  env            = "dev"
  workspace_name = "chhyun"

  aws_arn             = data.aws_caller_identity.current.arn
  aws_user_id         = data.aws_caller_identity.current.user_id
  aws_account_id      = data.aws_caller_identity.current.account_id
  pem_key_name        = "chhyun"
  pem_key_path        = "/Users/chhyun/Documents/pem/chhyun.pem"
  pem_public_key_path = "/Users/chhyun/Documents/pem/chhyun.pub.pem"
  pem_public_content  = file("/Users/chhyun/Documents/pem/chhyun.pub.pem")
  vpc_cidr_block      = data.terraform_remote_state.vpc.outputs.vpc_cidr_block
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_private_subnets = data.terraform_remote_state.vpc.outputs.private_subnets
  allow_ips = [
    "10.10.0.0/16",
    "10.2.0.0/16",
  ]
  ec2_user = "chhyun"

  default_tags = {
    Env          = local.env
    Name         = "chhyun-development"
    "managed-by" = "terraform"
    "release"    = "chhyun-development"
  }
}


