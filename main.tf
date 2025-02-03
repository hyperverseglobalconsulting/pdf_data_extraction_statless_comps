terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket  = "pdfextractor-serverless"
    key     = "terraform/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
    profile = "pdfreader"
  }
}

provider "aws" {
  profile = "pdfreader"
}

# Configure us-east-1 for CloudFront and ACM
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
  profile = "pdfreader"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
