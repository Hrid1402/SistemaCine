terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
  key          = "lab09/dev/terraform.tfstate"
  encrypt      = true
  use_lockfile = true
}
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}