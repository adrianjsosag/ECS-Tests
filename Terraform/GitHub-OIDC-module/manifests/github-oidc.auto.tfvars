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
