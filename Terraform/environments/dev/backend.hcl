# Backend of the "dev" environment: S3 bucket created by bootstrap/ (terraform output backend_hcl)
# Used by every project: terraform init -backend-config=<path>/environments/dev/backend.hcl
bucket = "cloudengineering-dev-tfstate-373716886058"
region = "us-east-1"
