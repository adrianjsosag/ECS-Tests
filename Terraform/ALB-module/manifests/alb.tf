# AWS Application Load Balancer Terraform Module
# Public ALB in the 3 public subnets with an HTTP :80 listener.
# Target groups and listener rules are created by each service (ECS-services-module),
# so adding a new service does not require changes in this module.
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.1"

  name               = local.alb_name
  load_balancer_type = "application"

  vpc_id  = data.terraform_remote_state.vpc.outputs.vpc_id
  subnets = data.terraform_remote_state.vpc.outputs.public_subnets

  enable_deletion_protection = var.alb_enable_deletion_protection
  idle_timeout               = var.alb_idle_timeout

  # Security Group - HTTP (80) from the allowed CIDR blocks
  security_group_ingress_rules = {
    for cidr in var.alb_allowed_cidrs : "http_${replace(replace(cidr, ".", "_"), "/", "_")}" => {
      description = "HTTP from ${cidr}"
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = cidr
    }
  }
  # Security Group - the ALB only talks to the targets inside the VPC
  security_group_egress_rules = {
    vpc = {
      description = "All traffic to the VPC (ECS tasks)"
      ip_protocol = "-1"
      cidr_ipv4   = data.terraform_remote_state.vpc.outputs.vpc_cidr_block
    }
  }

  # HTTP listener - returns 404 unless a service listener rule matches the request
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      fixed_response = {
        content_type = "text/plain"
        message_body = "404: no hay ningun servicio en esta ruta"
        status_code  = "404"
      }
    }
  }

  tags = local.common_tags
}
