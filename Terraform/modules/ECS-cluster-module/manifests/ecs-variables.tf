# ECS Cluster Terraform Variables

# CloudWatch Container Insights
variable "ecs_container_insights" {
  description = "Enable or disable CloudWatch Container Insights on the cluster"
  type        = string
  default     = "disabled"
  validation {
    condition     = contains(["enabled", "disabled"], var.ecs_container_insights)
    error_message = "ecs_container_insights must be \"enabled\" or \"disabled\"."
  }
}
