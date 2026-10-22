# EC2 Bastion Host Variables
instance_type = "t3.micro"
# Recommended: replace with your own public IP, e.g. ["203.0.113.10/32"]
bastion_ssh_allowed_cidrs = ["0.0.0.0/0"]
