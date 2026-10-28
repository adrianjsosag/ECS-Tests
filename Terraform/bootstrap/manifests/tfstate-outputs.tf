# S3 Terraform State Bucket Outputs

output "state_bucket" {
  description = "S3 bucket of the Terraform states of this environment (value of 'bucket' in environments/<env>/backend.hcl)"
  value       = aws_s3_bucket.tfstate.bucket
}

output "aws_region" {
  description = "Region of the state bucket (value of 'region' in environments/<env>/backend.hcl)"
  value       = var.aws_region
}

output "backend_hcl" {
  description = "Content of environments/<env>/backend.hcl (partial backend configuration of every project)"
  value       = <<-EOT
    bucket = "${aws_s3_bucket.tfstate.bucket}"
    region = "${var.aws_region}"
  EOT
}
