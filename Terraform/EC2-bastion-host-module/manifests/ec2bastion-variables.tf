# AWS EC2 Instance Terraform Variables

# AWS EC2 Instance Type
variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.micro"
}

# CIDR blocks allowed to connect to the Bastion Host via SSH
variable "bastion_ssh_allowed_cidrs" {
  description = "List of IPv4 CIDR blocks allowed to connect via SSH (port 22) to the Bastion Host"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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
