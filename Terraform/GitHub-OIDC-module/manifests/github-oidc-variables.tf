# GitHub Actions OIDC Terraform Variables

# GitHub repository whose workflows can assume the roles
variable "github_repository" {
  description = "GitHub repository (owner/name) whose workflows can assume the CI roles"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must have the format owner/name, e.g. adrianjsosag/ECS-Tests."
  }
}

# Create the OIDC provider (false if the account already has token.actions.githubusercontent.com)
variable "create_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider (false = use the one that already exists in the account)"
  type        = bool
  default     = true
}

# One IAM role per app CI. The key is the app name: role CloudEngineering-dev-gha-<key>
variable "github_ci_roles" {
  description = "One IAM role per app CI. Key = app name (role <business_division>-<environment>-gha-<key>)"
  type = map(object({
    app_path         = string                           # App directory in the repository (documentation + tag)
    workflow_file    = string                           # Workflow that assumes the role (documentation + tag)
    ecr_repositories = list(string)                     # ECR-module repository keys the role can push to
    branches         = optional(list(string), ["main"]) # Branches allowed to assume the role
  }))
  default = {}

  validation {
    # IAM role names are limited to 64 characters: "CloudEngineering-dev-gha-" + key
    condition     = alltrue([for app in keys(var.github_ci_roles) : can(regex("^[a-z0-9][a-z0-9-]{0,38}$", app))])
    error_message = "github_ci_roles keys must be lowercase letters, numbers or '-' (max 39 characters)."
  }
  validation {
    condition     = alltrue([for cfg in values(var.github_ci_roles) : length(cfg.ecr_repositories) > 0 && length(cfg.branches) > 0])
    error_message = "Every entry of github_ci_roles needs at least one ECR repository and one branch."
  }
}

# S3 bucket with the Terraform states (S3-tfstate-backend-module). Default: <division>-<environment>-tfstate-<account_id>
variable "state_bucket" {
  description = "S3 bucket of the Terraform states (null = name derived like S3-tfstate-backend-module)"
  type        = string
  default     = null
}

# TESTS ONLY: directory with local <project>.tfstate files used instead of the S3 bucket
variable "remote_state_local_dir" {
  description = "Tests only: directory with local <project>.tfstate files (e.g. ECR-module.tfstate) instead of S3"
  type        = string
  default     = null
}

# CD of the ECS services (github-services-cd.tf): plan and apply roles of .github/workflows/terraform-services-cd.yml
# null = do not create the roles
variable "services_cd" {
  description = "CD of the ECS services: workflow that assumes the roles, GitHub environment of the apply job and branches allowed to plan"
  type = object({
    workflow_file  = string                           # Workflow that assumes the roles (documentation + tag)
    environment    = string                           # GitHub environment of the apply job (manual approval)
    plan_branches  = optional(list(string), ["main"]) # Branches allowed to assume the plan role (pull requests always can)
    apply_branches = optional(list(string), ["main"]) # Branches allowed to assume the apply role (inside the environment)
  })
  default = null

  validation {
    condition     = var.services_cd == null || can(regex("^[A-Za-z0-9_.-]+$", var.services_cd.environment))
    error_message = "services_cd.environment must be the name of a GitHub environment, e.g. dev."
  }
}
