# Application Load Balancer Terraform Outputs

## alb_arn
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.arn
}

## alb_dns_name
output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

## alb_zone_id
output "alb_zone_id" {
  description = "Hosted zone ID of the ALB (for Route 53 alias records)"
  value       = module.alb.zone_id
}

## alb_url
output "alb_url" {
  description = "HTTP URL of the Application Load Balancer"
  value       = "http://${module.alb.dns_name}"
}

## alb_security_group_id
output "alb_security_group_id" {
  description = "ID of the ALB Security Group (allowed as source by the ECS services)"
  value       = module.alb.security_group_id
}

## http_listener_arn
output "http_listener_arn" {
  description = "ARN of the HTTP :80 listener (the ECS services attach their listener rules to it)"
  value       = module.alb.listeners["http"].arn
}
