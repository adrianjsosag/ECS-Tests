# ECS Cluster Terraform Outputs

## cluster_name
output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.name
}

## cluster_arn
output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs_cluster.arn
}

## cluster_id
output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs_cluster.id
}

## cluster_capacity_providers (FARGATE, FARGATE_SPOT)
output "cluster_capacity_providers" {
  description = "Capacity providers available in the ECS cluster"
  value       = ["FARGATE", "FARGATE_SPOT"]
}
