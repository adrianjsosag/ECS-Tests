# Define Local Values in Terraform
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }

  # One IAM role per app CI: CloudEngineering-dev-gha-<app>
  role_names = { for app in keys(var.github_ci_roles) : app => "${local.name}-gha-${app}" }

  # Full ECR repository names of each role: cloudengineering-dev/<repository>
  ecr_repository_names = { for app, cfg in var.github_ci_roles : app => [for repo in cfg.ecr_repositories : "${lower(local.name)}/${repo}"] }

  # OIDC provider created here or the one that already exists in the account
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}
