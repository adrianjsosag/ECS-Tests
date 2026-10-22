# Terraform Block
terraform {
  required_version = ">= 1.16"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }
}

# Provider Block - credentials from the default AWS chain (AWS_PROFILE, environment variables or the default profile of ~/.aws/credentials)
provider "aws" {
  region = var.aws_region
}
