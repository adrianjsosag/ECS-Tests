# Define Local Values in Terraform
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }

  # Bucket names are global and lowercase: <division>-<environment>-tfstate-<account_id>
  # (environments/<env>/backend.hcl must use this name; the projects derive it in remote-state-datasource.tf)
  state_bucket = "${lower(local.name)}-tfstate-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}
