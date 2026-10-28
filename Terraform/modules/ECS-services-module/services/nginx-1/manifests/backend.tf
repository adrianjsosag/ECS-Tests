# Terraform state in the S3 bucket of the environment, created by bootstrap/ (one bucket per environment, one key per service).
# Backends cannot use variables: "bucket" and "region" come from environments/<env>/backend.hcl:
#   terraform init -backend-config=../../../../../environments/dev/backend.hcl
# A copied service MUST get its own "key", otherwise it would share (and overwrite) another service's state.
terraform {
  backend "s3" {
    key          = "ECS-services-module/services/nginx-1/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
