# AWS EC2 Security Group
# Security Group for Public Bastion Host
resource "aws_security_group" "bastion" {
  name        = "${local.name}-public-bastion-sg"
  description = "Security Group with SSH port open for the allowed CIDR blocks, egress ports are all world open"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name}-public-bastion-sg" })
}

# Ingress Rule - SSH (22) from each allowed CIDR block
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  for_each          = toset(var.bastion_ssh_allowed_cidrs)
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from ${each.value}"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# Egress Rule - all-all open
resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow all outbound IPv4 traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
