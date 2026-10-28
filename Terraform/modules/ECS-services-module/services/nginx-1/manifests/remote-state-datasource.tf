# Terraform Remote State Datasource
# The states live in the S3 bucket of the environment, created by bootstrap/ (one key per project).
# Tests only: set remote_state_local_dir to read local <project>.tfstate files instead of S3.

data "aws_caller_identity" "current" {}

locals {
  state_bucket = coalesce(var.state_bucket, "${lower(var.business_division)}-${lower(var.environment)}-tfstate-${data.aws_caller_identity.current.account_id}")

  # Backend configuration of each remote state: S3 (default) or local files (tests)
  remote_state_config = {
    for project, key in {
      vpc         = "VPC-module"
      alb         = "ALB-module"
      ecs_cluster = "ECS-cluster-module"
      ecr         = "ECR-module"
      } : project => (
      var.remote_state_local_dir == null
      ? tomap({ bucket = local.state_bucket, key = "${key}/terraform.tfstate", region = var.aws_region })
      : tomap({ path = "${var.remote_state_local_dir}/${key}.tfstate" })
    )
  }
  remote_state_backend = var.remote_state_local_dir == null ? "s3" : "local"
}

# VPC project outputs (vpc_id, private_subnets)
data "terraform_remote_state" "vpc" {
  backend = local.remote_state_backend
  config  = local.remote_state_config["vpc"]
}

# ALB project outputs (http_listener_arn, alb_security_group_id, alb_url)
data "terraform_remote_state" "alb" {
  backend = local.remote_state_backend
  config  = local.remote_state_config["alb"]
}

# ECS cluster project outputs (cluster_arn, cluster_name)
data "terraform_remote_state" "ecs_cluster" {
  backend = local.remote_state_backend
  config  = local.remote_state_config["ecs_cluster"]
}

# ECR project outputs (repository_urls, repository_names)
data "terraform_remote_state" "ecr" {
  backend = local.remote_state_backend
  config  = local.remote_state_config["ecr"]
}

# Image pushed with push-image.sh: fails the plan if the tag does not exist in the repository
data "aws_ecr_image" "this" {
  repository_name = data.terraform_remote_state.ecr.outputs.repository_names[var.ecr_repository]
  image_tag       = var.image_tag
}
