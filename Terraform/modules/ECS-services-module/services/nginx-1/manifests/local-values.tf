# Define Local Values in Terraform
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
    service     = var.service_name
  }
  # Service resource names: CloudEngineering-dev-nginx-1
  service_full_name = "${local.name}-${var.service_name}"
  # Target group names are limited to 32 characters
  target_group_name = substr("${local.service_full_name}-tg", 0, 32)

  # Image pinned by digest: a new push with the same tag can never change what runs
  image = "${data.terraform_remote_state.ecr.outputs.repository_urls[var.ecr_repository]}@${data.aws_ecr_image.this.image_digest}"
}
