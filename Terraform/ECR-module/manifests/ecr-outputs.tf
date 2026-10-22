# ECR Terraform Outputs

data "aws_caller_identity" "current" {}

## registry_url
output "registry_url" {
  description = "URL of the private ECR registry (used by docker login)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

## repository_urls (short name -> URL)
output "repository_urls" {
  description = "URL of each repository, by short name (used by push-image.sh and by the ECS services)"
  value       = { for key, repo in module.ecr : key => repo.repository_url }
}

## repository_names (short name -> full name)
output "repository_names" {
  description = "Full name of each repository, by short name"
  value       = { for key, repo in module.ecr : key => repo.repository_name }
}

## repository_arns (short name -> ARN)
output "repository_arns" {
  description = "ARN of each repository, by short name"
  value       = { for key, repo in module.ecr : key => repo.repository_arn }
}
