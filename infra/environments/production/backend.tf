terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Production uses a separate bucket/key to isolate state.
    bucket         = "cloudzone-tfstate-952868634839"
    key            = "production/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "aws-infra-assignment"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
