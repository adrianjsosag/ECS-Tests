# GitHub Actions OIDC Terraform Outputs

## oidc_provider_arn (shared by every CI role)
output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider (shared by every CI role)"
  value       = local.oidc_provider_arn
}

## role_arns (app -> role ARN): value of the GitHub secret AWS_ROLE_ARN of each workflow
output "role_arns" {
  description = "ARN of each CI role, by app. role_arns[\"countdown-new-year\"] is the GitHub secret AWS_ROLE_ARN of countdown-new-year-ci.yml"
  value       = { for app, role in aws_iam_role.github_ci : app => role.arn }
}

## roles_usage (app -> who uses the role and what it allows)
output "roles_usage" {
  description = "Which app and workflow use each CI role, and what the role allows"
  value = {
    for app, cfg in var.github_ci_roles : app => {
      role_name        = local.role_names[app]
      app_path         = cfg.app_path
      workflow_file    = cfg.workflow_file
      github_secret    = "AWS_ROLE_ARN"
      ecr_repositories = local.ecr_repository_names[app]
      branches         = cfg.branches
    }
  }
}
