# S3 Terraform State Bucket Outputs

output "state_bucket" {
  description = "S3 bucket of the Terraform states (value of 'bucket' in every backend.tf)"
  value       = aws_s3_bucket.tfstate.bucket
}

output "aws_region" {
  description = "Region of the state bucket (value of 'region' in every backend.tf)"
  value       = var.aws_region
}

output "backend_tf_example" {
  description = "backend.tf for a project: replace the key with the project path"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.tfstate.bucket}"
        key          = "<Proyecto>/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true
      }
    }
  EOT
}
