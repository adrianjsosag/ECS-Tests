# AWS ECR Terraform Module
# One private ECR repository per application, with immutable tags, scan on push and a lifecycle policy.
module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.2.0"

  for_each = var.repositories

  repository_name = "${local.repo_prefix}/${each.key}"
  repository_type = "private"

  # Immutable tags: a tag (e.g. 1.0.0) can never be overwritten with a different image
  repository_image_tag_mutability = each.value.image_tag_mutability

  # Basic vulnerability scan of every pushed image (free)
  repository_image_scan_on_push = true

  # Encryption at rest (AES256 managed by AWS; KMS CMK is a DevSecOps improvement)
  repository_encryption_type = "AES256"

  # Laboratory convenience: allow destroy with images inside (see ecr.auto.tfvars)
  repository_force_delete = var.ecr_force_delete

  # Same-account access is granted through IAM (ECS task execution roles already can pull),
  # so no repository policy is created
  create_repository_policy = false
  attach_repository_policy = false

  # Lifecycle policy: expire untagged images and keep only the most recent ones
  create_lifecycle_policy = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.ecr_untagged_expire_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_untagged_expire_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${coalesce(each.value.max_image_count, var.ecr_max_image_count)} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = coalesce(each.value.max_image_count, var.ecr_max_image_count)
        }
        action = { type = "expire" }
      }
    ]
  })

  tags = merge(local.common_tags, { Repository = each.key })
}
