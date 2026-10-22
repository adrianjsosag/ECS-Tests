# ECS Service Terraform Variables

# Short name of the service (resource names, container name and tags)
variable "service_name" {
  description = "Short name of the ECS service"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,30}$", var.service_name))
    error_message = "service_name must be lowercase letters, numbers or '-' (max 31 characters)."
  }
}

# Image: ECR repository (short name in ECR-module) and tag pushed with push-image.sh
variable "ecr_repository" {
  description = "Short name of the ECR repository (key of repositories in ECR-module)"
  type        = string
}

variable "image_tag" {
  description = "Image tag pushed with push-image.sh (the service runs it pinned by digest)"
  type        = string
  validation {
    condition     = var.image_tag != "latest"
    error_message = "image_tag must be a version (e.g. 1.0.0), not \"latest\"."
  }
}

# Port the container listens on
variable "container_port" {
  description = "Port the container listens on (also the target group port)"
  type        = number
  default     = 80
}

# Fargate task size (valid Fargate CPU/memory combination)
variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

# Number of running tasks
variable "desired_count" {
  description = "Number of tasks the service keeps running"
  type        = number
  default     = 1
}

# ALB listener rule
variable "listener_rule_priority" {
  description = "Priority of the listener rule in the ALB HTTP listener (unique per listener)"
  type        = number
  default     = 100
}

variable "path_patterns" {
  description = "Path patterns routed to this service by the ALB"
  type        = list(string)
  default     = ["/*"]
}

# Target group health check
variable "health_check_path" {
  description = "HTTP path used by the ALB health check"
  type        = string
  default     = "/"
}

# CloudWatch Logs retention of the container logs
variable "log_retention_days" {
  description = "Retention (days) of the container logs in CloudWatch"
  type        = number
  default     = 7
}

# S3 bucket with the Terraform states (S3-tfstate-backend-module). Default: <division>-<environment>-tfstate-<account_id>
variable "state_bucket" {
  description = "S3 bucket of the Terraform states (null = name derived like S3-tfstate-backend-module)"
  type        = string
  default     = null
}

# TESTS ONLY: directory with local <project>.tfstate files used instead of the S3 bucket
variable "remote_state_local_dir" {
  description = "Tests only: directory with local <project>.tfstate files (e.g. VPC-module.tfstate) instead of S3"
  type        = string
  default     = null
}
