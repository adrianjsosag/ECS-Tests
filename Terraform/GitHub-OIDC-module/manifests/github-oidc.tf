# GitHub Actions OIDC - IAM roles assumed by the CI workflows of this repository
# GitHub exchanges a short-lived OIDC token for temporary AWS credentials: no AWS keys are stored in GitHub.
#
# One IAM role per app CI (one entry of github_ci_roles in github-oidc.auto.tfvars).
# Roles created today:
#
#   CloudEngineering-dev-gha-countdown-new-year
#     App:       apps/countdown-new-year
#     Used by:   .github/workflows/countdown-new-year-ci.yml, job "push"
#     Secret:    AWS_ROLE_ARN of the GitHub repository = output role_arns["countdown-new-year"]
#     Allows:    push images ONLY to cloudengineering-dev/countdown-new-year, ONLY from the main branch
#
# Adding a role for another app: new entry in github_ci_roles (see README "Añadir un rol para otra app").

# OIDC identity provider of GitHub Actions - only one per AWS account, shared by every role below
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = merge(local.common_tags, { Name = "github-actions-oidc", used_by = "GitHub Actions (all CI roles of this module)" })
}

# Provider already created outside this project (create_oidc_provider = false)
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# Trust policy of each role - only the workflows of github_repository running on the allowed branches
data "aws_iam_policy_document" "github_ci_trust" {
  for_each = var.github_ci_roles

  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    # The token was issued for AWS STS
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only this repository and these branches (pull requests and other repositories cannot assume it)
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for branch in each.value.branches : "repo:${var.github_repository}:ref:refs/heads/${branch}"]
    }
  }
}

# IAM role of each app CI: CloudEngineering-dev-gha-<app>
# Description and tags say which app and which workflow use it (also visible in the IAM console)
resource "aws_iam_role" "github_ci" {
  for_each = var.github_ci_roles

  name                 = local.role_names[each.key]
  description          = "GitHub Actions CI of ${each.value.app_path} (${each.value.workflow_file}): push to ECR ${join(", ", local.ecr_repository_names[each.key])}"
  assume_role_policy   = data.aws_iam_policy_document.github_ci_trust[each.key].json
  max_session_duration = 3600

  tags = merge(local.common_tags, {
    app      = each.key
    app_path = each.value.app_path
    workflow = each.value.workflow_file
    used_by  = "GitHub Actions"
  })
}

# Permissions of each role - push only to the ECR repositories of its app
data "aws_iam_policy_document" "github_ci_ecr_push" {
  for_each = var.github_ci_roles

  # docker login (GetAuthorizationToken only works with Resource "*")
  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Push the image, check whether the tag exists (IMMUTABLE) and read the scan result
  statement {
    sid    = "PushToAppRepositories"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
    ]
    resources = [
      for repo in each.value.ecr_repositories : data.terraform_remote_state.ecr.outputs.repository_arns[repo]
      if contains(keys(data.terraform_remote_state.ecr.outputs.repository_arns), repo)
    ]
  }
}

resource "aws_iam_role_policy" "github_ci_ecr_push" {
  for_each = var.github_ci_roles

  name   = "ecr-push-${each.key}"
  role   = aws_iam_role.github_ci[each.key].id
  policy = data.aws_iam_policy_document.github_ci_ecr_push[each.key].json

  lifecycle {
    precondition {
      condition     = alltrue([for repo in each.value.ecr_repositories : contains(keys(data.terraform_remote_state.ecr.outputs.repository_arns), repo)])
      error_message = "github_ci_roles[\"${each.key}\"].ecr_repositories contains repositories that ECR-module does not create. Add them to ECR-module/manifests/ecr.auto.tfvars and apply it first."
    }
  }
}
