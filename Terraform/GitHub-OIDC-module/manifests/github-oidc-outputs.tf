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

## roles_usage (role -> who uses it and what it allows)
output "roles_usage" {
  description = "Which app/workflow uses each role (CI of the apps and CD of the services), and what the role allows"
  value = merge(
    {
      for app, cfg in var.github_ci_roles : app => {
        role_name     = local.role_names[app]
        workflow_file = cfg.workflow_file
        job           = "push"
        github_secret = "AWS_ROLE_ARN"
        allows        = "push to ECR ${join(", ", local.ecr_repository_names[app])} from ${join(", ", cfg.branches)}"
      }
    },
    {
      for key, role in local.services_cd_roles : "services-cd-${key}" => {
        role_name     = role.name
        workflow_file = var.services_cd.workflow_file
        job           = role.job
        github_secret = role.secret
        allows        = key == "plan" ? "read-only terraform plan of the ECS services (pull requests and ${join(", ", var.services_cd.plan_branches)})" : "terraform apply of the ECS services, only from the GitHub environment ${var.services_cd.environment}"
      }
    }
  )
}

## services_cd_role_arns (plan / apply): GitHub secrets AWS_SERVICES_PLAN_ROLE_ARN / AWS_SERVICES_APPLY_ROLE_ARN
output "services_cd_role_arns" {
  description = "ARNs of the CD roles of the ECS services: plan = secret AWS_SERVICES_PLAN_ROLE_ARN, apply = secret AWS_SERVICES_APPLY_ROLE_ARN"
  value       = { for key, role in aws_iam_role.services_cd : key => role.arn }
}
