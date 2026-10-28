# Define Local Values in Terraform
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
  # Application Load Balancer name (max 32 characters)
  alb_name = "${local.name}-alb"
}
