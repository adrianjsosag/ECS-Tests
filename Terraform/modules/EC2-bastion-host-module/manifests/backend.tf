# Terraform state in the S3 bucket of the environment, created by bootstrap/ (one bucket per environment, one key per project).
# Backends cannot use variables: "bucket" and "region" come from environments/<env>/backend.hcl:
#   terraform init -backend-config=../../../environments/dev/backend.hcl
# A copied project MUST get its own "key", otherwise it would share (and overwrite) another project's state.
terraform {
  backend "s3" {
    key          = "EC2-bastion-host-module/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
