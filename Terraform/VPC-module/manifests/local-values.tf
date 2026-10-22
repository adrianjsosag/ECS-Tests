# Define Local Values in Terraform
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  #name = "${local.owners}-${local.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
  # Use the AZs given in var.vpc_availability_zones, otherwise the first 3 available AZs in the region
  azs = length(var.vpc_availability_zones) > 0 ? var.vpc_availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
} 