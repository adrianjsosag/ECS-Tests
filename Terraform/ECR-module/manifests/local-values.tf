# Define Local Values in Terraform
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
  # ECR repository names must be lowercase: cloudengineering-dev/<repository>
  repo_prefix = lower(local.name)
}
