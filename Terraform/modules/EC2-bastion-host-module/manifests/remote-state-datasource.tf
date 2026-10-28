# Terraform Remote State Datasource
# The states live in the S3 bucket of the environment, created by bootstrap/ (one key per project).
# Tests only: set remote_state_local_dir to read local <project>.tfstate files instead of S3.

data "aws_caller_identity" "current" {}

locals {
  state_bucket = coalesce(var.state_bucket, "${lower(var.business_division)}-${lower(var.environment)}-tfstate-${data.aws_caller_identity.current.account_id}")

  # Backend configuration of each remote state: S3 (default) or local files (tests)
  remote_state_config = {
    for project, key in { vpc = "VPC-module" } : project => (
      var.remote_state_local_dir == null
      ? tomap({ bucket = local.state_bucket, key = "${key}/terraform.tfstate", region = var.aws_region })
      : tomap({ path = "${var.remote_state_local_dir}/${key}.tfstate" })
    )
  }
  remote_state_backend = var.remote_state_local_dir == null ? "s3" : "local"
}

# VPC project outputs (vpc_id, public_subnets, ...)
data "terraform_remote_state" "vpc" {
  backend = local.remote_state_backend
  config  = local.remote_state_config["vpc"]
}
