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

## service_connect_namespace_arn / service_connect_namespace_name
output "service_connect_namespace_arn" {
  description = "ARN of the ECS Service Connect namespace (used by the services that talk to each other)"
  value       = aws_service_discovery_http_namespace.this.arn
}

output "service_connect_namespace_name" {
  description = "Name of the ECS Service Connect namespace"
  value       = aws_service_discovery_http_namespace.this.name
}

## cluster_capacity_providers (FARGATE, FARGATE_SPOT)
output "cluster_capacity_providers" {
  description = "Capacity providers available in the ECS cluster"
  value       = ["FARGATE", "FARGATE_SPOT"]
}
