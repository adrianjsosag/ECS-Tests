# S3 Terraform State Bucket Variables

# Days to keep old (non-current) versions of the state files
variable "state_noncurrent_version_days" {
  description = "Days after which non-current versions of the state objects are deleted"
  type        = number
  default     = 90
  validation {
    condition     = var.state_noncurrent_version_days >= 1
    error_message = "state_noncurrent_version_days must be 1 or greater."
  }
}
