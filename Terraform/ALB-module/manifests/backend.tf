# Terraform state in the S3 bucket created by S3-tfstate-backend-module (one key per project).
# Backends cannot use variables: if the AWS account, division or environment change, update "bucket"
# here and in the other projects (see the README of S3-tfstate-backend-module).
# A copied project MUST get its own "key", otherwise it would share (and overwrite) another project's state.
terraform {
  backend "s3" {
    bucket       = "cloudengineering-dev-tfstate-373716886058"
    key          = "ALB-module/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
