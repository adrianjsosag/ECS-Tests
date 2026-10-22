# GitHub Actions OIDC Variables
github_repository    = "adrianjsosag/ECS-Tests"
create_oidc_provider = true

# One IAM role per app CI (role name: CloudEngineering-dev-gha-<key>)
github_ci_roles = {
  # Role: CloudEngineering-dev-gha-countdown-new-year
  # App:      apps/countdown-new-year
  # Used by:  .github/workflows/countdown-new-year-ci.yml, job "push" (GitHub secret AWS_ROLE_ARN)
  # Allows:   push images ONLY to cloudengineering-dev/countdown-new-year, ONLY from the main branch
  countdown-new-year = {
    app_path         = "apps/countdown-new-year"
    workflow_file    = ".github/workflows/countdown-new-year-ci.yml"
    ecr_repositories = ["countdown-new-year"]
    branches         = ["main"]
  }
}

# CD of the ECS services (github-services-cd.tf)
# Roles: CloudEngineering-dev-gha-services-cd-plan  (job "plan", GitHub secret AWS_SERVICES_PLAN_ROLE_ARN)
#        CloudEngineering-dev-gha-services-cd-apply (job "apply", GitHub secret AWS_SERVICES_APPLY_ROLE_ARN)
# Used by: .github/workflows/terraform-services-cd.yml, deploys Terraform/ECS-services-module/services/<service>
# Allows:  plan = read only (pull requests and main); apply = only the resources of a service,
#          only from jobs of the GitHub environment "dev" (manual approval) running on main
services_cd = {
  workflow_file  = ".github/workflows/terraform-services-cd.yml"
  environment    = "dev"
  plan_branches  = ["main"]
  apply_branches = ["main"]
}
