# AWS EC2 Instance Terraform Outputs
# Public EC2 Instances - Bastion Host

## ec2_bastion_public_instance_ids
output "ec2_bastion_public_instance_ids" {
  description = "ID of the Bastion Host instance"
  value       = module.ec2_public.id
}

## ec2_bastion_public_ip
output "ec2_bastion_eip" {
  description = "Elastic IP associated to the Bastion Host"
  value       = aws_eip.bastion_eip.public_ip
}

## ec2_bastion_private_ip
output "ec2_bastion_private_ip" {
  description = "Private IP of the Bastion Host inside the VPC"
  value       = module.ec2_public.private_ip
}

## ec2_bastion_availability_zone
output "ec2_bastion_availability_zone" {
  description = "Availability Zone where the Bastion Host was created"
  value       = module.ec2_public.availability_zone
}

## bastion_security_group_id
output "bastion_security_group_id" {
  description = "ID of the Bastion Host Security Group"
  value       = aws_security_group.bastion.id
}

## vpc_id (read from the VPC remote state)
output "vpc_id" {
  description = "ID of the VPC where the Bastion Host was created (read from the VPC state)"
  value       = data.terraform_remote_state.vpc.outputs.vpc_id
}

## key_pair_name (same name as the Bastion Host)
output "key_pair_name" {
  description = "Name of the Key Pair created for the Bastion Host"
  value       = module.key_pair.key_pair_name
}

## private_key_path
output "private_key_path" {
  description = "Local path of the private key (.pem) to connect to the Bastion Host"
  value       = local_sensitive_file.bastion_private_key.filename
}

## ssh_command
output "ssh_command" {
  description = "Command to connect to the Bastion Host via SSH"
  value       = "ssh -i ${local_sensitive_file.bastion_private_key.filename} ec2-user@${aws_eip.bastion_eip.public_ip}"
}
