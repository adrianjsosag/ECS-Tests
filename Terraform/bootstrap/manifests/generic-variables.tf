# Input Variables
# AWS Region
variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type        = string
  default     = "us-east-1"
}
# Environment Variable - no default: it comes from environments/<env>/common.tfvars (-var-file)
variable "environment" {
  description = "Environment Variable used as a prefix (dev, qa, prod...)"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*$", var.environment))
    error_message = "environment must be lowercase letters and digits (e.g. dev); it is part of the state bucket name."
  }
}
# Business Division - no default: it comes from environments/<env>/common.tfvars (-var-file)
variable "business_division" {
  description = "Business Division in the large organization this Infrastructure belongs"
  type        = string
}
