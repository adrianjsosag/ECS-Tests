# State of the bootstrap itself: it lives in the bucket that the bootstrap creates (key bootstrap/terraform.tfstate).
# The first apply runs with a temporary local backend and bootstrap.sh then migrates the state here
# (terraform init -migrate-state). "bucket" and "region" come from environments/<env>/backend.hcl.
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
