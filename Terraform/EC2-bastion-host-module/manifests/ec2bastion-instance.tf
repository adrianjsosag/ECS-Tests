# AWS EC2 Instance Terraform Module
# Bastion Host - EC2 Instance that will be created in the first VPC Public Subnet
module "ec2_public" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.4.1"

  name          = local.bastion_name
  ami           = data.aws_ami.amzlinux2023.id
  instance_type = var.instance_type
  key_name      = module.key_pair.key_pair_name
  subnet_id     = data.terraform_remote_state.vpc.outputs.public_subnets[0]

  # A newer Amazon Linux 2023 AMI must not replace the running Bastion (replace it on purpose with -replace)
  ignore_ami_changes = true

  # Encrypted gp3 root volume
  root_block_device = {
    encrypted = true
    type      = "gp3"
  }

  # Use the Security Group defined in ec2bastion-securitygroups.tf instead of the module's own
  create_security_group  = false
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = local.common_tags
}
