# Application Load Balancer Terraform Variables

# IPv4 CIDR blocks allowed to reach the ALB over HTTP (port 80)
variable "alb_allowed_cidrs" {
  description = "List of IPv4 CIDR blocks allowed to connect to the ALB over HTTP (port 80)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Deletion protection (keep false in the lab so terraform destroy works)
variable "alb_enable_deletion_protection" {
  description = "If true, the ALB cannot be deleted via the AWS API (terraform destroy fails)"
  type        = bool
  default     = false
}

# Idle timeout in seconds
variable "alb_idle_timeout" {
  description = "Time in seconds that a connection is allowed to be idle"
  type        = number
  default     = 60
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
