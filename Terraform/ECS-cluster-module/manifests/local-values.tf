# Define Local Values in Terraform
locals {
  owners      = var.business_division
  environment = var.environment
  name        = "${var.business_division}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
  # ECS Cluster name
  cluster_name = "${local.name}-ecs-cluster"
  # ECS Service Connect namespace (Cloud Map): cloudengineering-dev
  service_connect_namespace = lower(local.name)
}
