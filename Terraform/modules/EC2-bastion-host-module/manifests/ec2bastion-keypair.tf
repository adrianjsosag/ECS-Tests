# AWS EC2 Key Pair Terraform Module
# Generates a new private key (ED25519) and registers its public key in AWS as a Key Pair
# The Key Pair has the same name as the Bastion Host
module "key_pair" {
  source  = "terraform-aws-modules/key-pair/aws"
  version = "3.0.1"

  key_name              = local.bastion_name
  create_private_key    = true
  private_key_algorithm = "ED25519"

  tags = local.common_tags
}

# Save the private key locally in private-key/<bastion_name>.pem (read-only for the owner)
resource "local_sensitive_file" "bastion_private_key" {
  content         = module.key_pair.private_key_openssh
  filename        = "${path.module}/private-key/${module.key_pair.key_pair_name}.pem"
  file_permission = "0400"
}
