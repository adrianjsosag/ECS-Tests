# ECS Service Terraform Outputs

## service_name
output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

## service_url
output "service_url" {
  description = "URL of the service through the ALB"
  value       = data.terraform_remote_state.alb.outputs.alb_url
}

## image
output "image" {
  description = "Image running in the service (pinned by digest)"
  value       = local.image
}

## task_definition_arn
output "task_definition_arn" {
  description = "ARN of the task definition revision deployed"
  value       = aws_ecs_task_definition.this.arn
}

## target_group_arn
output "target_group_arn" {
  description = "ARN of the ALB target group of the service"
  value       = aws_lb_target_group.this.arn
}

## tasks_security_group_id
output "tasks_security_group_id" {
  description = "ID of the Security Group of the tasks"
  value       = aws_security_group.tasks.id
}

## log_group_name
output "log_group_name" {
  description = "CloudWatch log group of the container logs"
  value       = aws_cloudwatch_log_group.this.name
}
