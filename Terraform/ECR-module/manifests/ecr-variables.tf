# ECR Terraform Variables

# Repositories to create: one per application (the map key is the short repository name)
variable "repositories" {
  description = "Map of ECR repositories to create. The key is the short name (full name: <business_division>-<environment>/<key>, lowercase)"
  type = map(object({
    image_tag_mutability = optional(string, "IMMUTABLE") # IMMUTABLE (recommended) or MUTABLE
    max_image_count      = optional(number)              # Overrides ecr_max_image_count for this repository
  }))
  default = {}

  validation {
    condition     = alltrue([for key in keys(var.repositories) : can(regex("^[a-z0-9][a-z0-9._-]{0,63}$", key))])
    error_message = "Repository keys must be lowercase: letters, numbers, '.', '_' or '-' (max 64 characters)."
  }
  validation {
    condition     = alltrue([for repo in values(var.repositories) : contains(["IMMUTABLE", "MUTABLE"], repo.image_tag_mutability)])
    error_message = "image_tag_mutability must be \"IMMUTABLE\" or \"MUTABLE\"."
  }
}

# Lifecycle policy - number of images kept per repository
variable "ecr_max_image_count" {
  description = "Number of most recent images kept per repository (older ones are expired)"
  type        = number
  default     = 10
  validation {
    condition     = var.ecr_max_image_count >= 1
    error_message = "ecr_max_image_count must be >= 1."
  }
}

# Lifecycle policy - days before untagged images are expired
variable "ecr_untagged_expire_days" {
  description = "Days after which untagged images are expired"
  type        = number
  default     = 7
  validation {
    condition     = var.ecr_untagged_expire_days >= 1
    error_message = "ecr_untagged_expire_days must be >= 1."
  }
}

# Allow terraform destroy to delete repositories that still contain images
variable "ecr_force_delete" {
  description = "If true, terraform destroy deletes the repositories even if they contain images"
  type        = bool
  default     = false
}
