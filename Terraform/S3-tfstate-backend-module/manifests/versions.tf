# Terraform Block
# This project keeps its OWN state LOCAL (manifests/terraform.tfstate): it creates the bucket where the
# other projects store theirs, so it cannot use that bucket as its backend.
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
