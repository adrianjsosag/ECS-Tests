# AWS ECS Cluster Terraform Module
# Fargate-only cluster: AWS manages the servers, each ECS service defines the network of its tasks.
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "7.6.1"

  name = local.cluster_name

  # CloudWatch Container Insights
  setting = [
    {
      name  = "containerInsights"
      value = var.ecs_container_insights
    }
  ]

  # Capacity Providers - AWS Fargate (on-demand) and Fargate Spot (cheaper, can be interrupted)
  cluster_capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # Tasks without an explicit strategy run on Fargate (on-demand)
  default_capacity_provider_strategy = {
    FARGATE = {
      weight = 100
      base   = 1
    }
  }

  # Only needed for ECS Managed Instances, not for Fargate
  create_security_group          = false
  create_infrastructure_iam_role = false

  cloudwatch_log_group_retention_in_days = 7

  tags = local.common_tags
}
