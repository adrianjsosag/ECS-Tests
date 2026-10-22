# GitHub Actions CD of the ECS services - IAM roles assumed by .github/workflows/terraform-services-cd.yml
# The workflow deploys (terraform plan/apply) the new or changed services of
# Terraform/ECS-services-module/services/<service>/manifests/.
#
# Two roles, so a pull request can never change infrastructure:
#
#   CloudEngineering-dev-gha-services-cd-plan
#     Used by:  .github/workflows/terraform-services-cd.yml, job "plan" (pull requests and the main branch)
#     Secret:   AWS_SERVICES_PLAN_ROLE_ARN = output services_cd_role_arns["plan"]
#     Allows:   READ ONLY - the states a service needs and Describe/List/Get of what a service creates.
#               Writes only the state lock files (*.tflock) of the services.
#
#   CloudEngineering-dev-gha-services-cd-apply
#     Used by:  .github/workflows/terraform-services-cd.yml, job "apply" (GitHub environment "dev", manual approval,
#               and only when the run comes from the main branch)
#     Secret:   AWS_SERVICES_APPLY_ROLE_ARN = output services_cd_role_arns["apply"]
#     Allows:   read (same as plan) + create/change/delete ONLY the resources of a service:
#               execution role, log group, Security Group, target group, listener rule,
#               task definition and ECS service, and write the states of the services.
#
# Neither role can read the state of the Bastion (it contains its SSH private key) nor
# write the state of the other modules.

locals {
  services_cd_enabled = var.services_cd != null

  # Names of the platform resources a service attaches to (same formulas as their modules)
  services_cd_cluster_name = "${local.name}-ecs-cluster" # ECS-cluster-module
  services_cd_alb_name     = "${local.name}-alb"         # ALB-module

  account_id = data.aws_caller_identity.current.account_id
  state_arn  = "arn:aws:s3:::${local.state_bucket}"

  services_cd_roles = local.services_cd_enabled ? {
    plan = {
      name        = "${local.name}-gha-services-cd-plan"
      description = "GitHub Actions CD of the ECS services (${var.services_cd.workflow_file}, job plan): read-only terraform plan"
      job         = "plan"
      secret      = "AWS_SERVICES_PLAN_ROLE_ARN"
      # Pull requests and the plan of the allowed branches
      subjects = concat(
        ["repo:${var.github_repository}:pull_request"],
        [for branch in var.services_cd.plan_branches : "repo:${var.github_repository}:ref:refs/heads/${branch}"]
      )
      # No ref condition: the ref of a pull request is refs/pull/<n>/merge (the role is read-only)
      refs = tolist([])
    }
    apply = {
      name        = "${local.name}-gha-services-cd-apply"
      description = "GitHub Actions CD of the ECS services (${var.services_cd.workflow_file}, job apply): terraform apply of the services"
      job         = "apply"
      secret      = "AWS_SERVICES_APPLY_ROLE_ARN"
      # Only jobs that run in the GitHub environment (manual approval)...
      subjects = ["repo:${var.github_repository}:environment:${var.services_cd.environment}"]
      # ...and only from the allowed branches (the environment alone does not fix the branch)
      refs = tolist([for branch in var.services_cd.apply_branches : "refs/heads/${branch}"])
    }
  } : {}
}

# Trust policy - GitHub OIDC tokens of this repository with the subjects of each role
data "aws_iam_policy_document" "services_cd_trust" {
  for_each = local.services_cd_roles

  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value.subjects
    }

    dynamic "condition" {
      for_each = length(each.value.refs) > 0 ? [each.value.refs] : []
      content {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:ref"
        values   = condition.value
      }
    }
  }
}

resource "aws_iam_role" "services_cd" {
  for_each = local.services_cd_roles

  name                 = each.value.name
  description          = each.value.description
  assume_role_policy   = data.aws_iam_policy_document.services_cd_trust[each.key].json
  max_session_duration = 3600

  tags = merge(local.common_tags, {
    app      = "services-cd"
    app_path = "Terraform/ECS-services-module/services"
    workflow = var.services_cd.workflow_file
    job      = each.value.job
    used_by  = "GitHub Actions"
  })
}

# READ permissions (plan and apply roles): what terraform plan of a service needs
data "aws_iam_policy_document" "services_cd_read" {
  count = local.services_cd_enabled ? 1 : 0

  # List the state bucket (backend and terraform_remote_state)
  statement {
    sid       = "StateBucketList"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }

  # Read ONLY the states a service uses: its own and the ones it reads (VPC, ALB, cluster, ECR)
  statement {
    sid     = "ReadServiceStates"
    actions = ["s3:GetObject"]
    resources = [
      "${local.state_arn}/ECS-services-module/services/*",
      "${local.state_arn}/VPC-module/terraform.tfstate",
      "${local.state_arn}/ALB-module/terraform.tfstate",
      "${local.state_arn}/ECS-cluster-module/terraform.tfstate",
      "${local.state_arn}/ECR-module/terraform.tfstate",
    ]
  }

  # Native S3 state locking (use_lockfile): <key>.tflock of the services
  statement {
    sid       = "ServiceStateLocks"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/ECS-services-module/services/*/terraform.tfstate.tflock"]
  }

  # Refresh of the resources of a service (these Describe/List actions do not support resource ARNs)
  statement {
    sid = "DescribeServiceResources"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "ecs:Describe*",
      "ecs:List*",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "logs:ListTagsLogGroup",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
    ]
    resources = ["*"]
  }

  # Execution roles of the services: CloudEngineering-dev-<service>-exec
  statement {
    sid = "ReadExecutionRoles"
    actions = [
      "iam:GetRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name}-*-exec"]
  }
}

# WRITE permissions (apply role only): create/change/delete the resources of a service
data "aws_iam_policy_document" "services_cd_write" {
  count = local.services_cd_enabled ? 1 : 0

  # Write the states of the services (never the ones of the other modules)
  statement {
    sid       = "WriteServiceStates"
    actions   = ["s3:PutObject"]
    resources = ["${local.state_arn}/ECS-services-module/services/*/terraform.tfstate"]
  }

  # Execution role of each service (aws_iam_role + aws_iam_role_policy_attachment)
  statement {
    sid = "ManageExecutionRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name}-*-exec"]
  }

  # Only the AWS managed policy for ECS task execution can be attached
  statement {
    sid       = "AttachTaskExecutionPolicyOnly"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name}-*-exec"]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
    }
  }

  # The task definition passes the execution role to ECS tasks only
  statement {
    sid       = "PassExecutionRolesToEcsTasks"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.name}-*-exec"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Container logs: /ecs/CloudEngineering-dev-ecs-cluster/<service>
  statement {
    sid = "ManageServiceLogGroups"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/ecs/${local.services_cd_cluster_name}/*",
    ]
  }

  # Security Group of the tasks and its rules
  statement {
    sid = "ManageTaskSecurityGroups"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:ModifySecurityGroupRules",
      "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
      "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  # Target group of each service: CloudEngineering-dev-<service>-tg
  statement {
    sid = "ManageServiceTargetGroups"
    actions = [
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = ["arn:aws:elasticloadbalancing:${var.aws_region}:${local.account_id}:targetgroup/${local.name}-*/*"]
  }

  # Listener rules of the services on the HTTP listener of the platform ALB
  statement {
    sid = "ManageServiceListenerRules"
    actions = [
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:SetRulePriorities",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
    ]
    resources = [
      "arn:aws:elasticloadbalancing:${var.aws_region}:${local.account_id}:listener/app/${local.services_cd_alb_name}/*",
      "arn:aws:elasticloadbalancing:${var.aws_region}:${local.account_id}:listener-rule/app/${local.services_cd_alb_name}/*",
    ]
  }

  # Task definitions (RegisterTaskDefinition does not support resource ARNs)
  statement {
    sid       = "RegisterTaskDefinitions"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition"]
    resources = ["*"]
  }

  # ECS services, only in the platform cluster
  statement {
    sid = "ManageServicesInPlatformCluster"
    actions = [
      "ecs:CreateService",
      "ecs:UpdateService",
      "ecs:DeleteService",
      "ecs:TagResource",
      "ecs:UntagResource",
    ]
    resources = [
      "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${local.services_cd_cluster_name}/*",
      "arn:aws:ecs:${var.aws_region}:${local.account_id}:task-definition/${local.name}-*:*",
    ]
  }
}

# Plan and apply roles: read permissions
resource "aws_iam_role_policy" "services_cd_read" {
  for_each = local.services_cd_roles

  name   = "services-cd-read"
  role   = aws_iam_role.services_cd[each.key].id
  policy = data.aws_iam_policy_document.services_cd_read[0].json
}

# Apply role only: write permissions
resource "aws_iam_role_policy" "services_cd_write" {
  count = local.services_cd_enabled ? 1 : 0

  name   = "services-cd-write"
  role   = aws_iam_role.services_cd["apply"].id
  policy = data.aws_iam_policy_document.services_cd_write[0].json
}
