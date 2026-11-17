terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key         = "lab09/dev/terraform.tfstate"
    encrypt     = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = "sa-east-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
    }
  }
}

provider "aws" {
  alias   = "dr"
  region  = "us-east-1"
  profile = var.aws_profile
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
    }
  }
}