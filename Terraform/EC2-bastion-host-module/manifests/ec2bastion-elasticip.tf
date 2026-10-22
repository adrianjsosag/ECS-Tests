# Create Elastic IP for Bastion Host
resource "aws_eip" "bastion_eip" {
  instance = module.ec2_public.id
  domain   = "vpc"
  tags     = merge(local.common_tags, { Name = "${local.name}-bastion-eip" })
}
