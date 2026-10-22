# Application Load Balancer Variables
# Recommended: restrict to your own public IP while testing, e.g. ["203.0.113.10/32"]
alb_allowed_cidrs              = ["0.0.0.0/0"]
alb_enable_deletion_protection = false
alb_idle_timeout               = 60
