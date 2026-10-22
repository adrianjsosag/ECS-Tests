# ECS Service Variables
service_name   = "nginx-1"
ecr_repository = "nginx-1" # pushed with: ECR-module/push-image.sh nginx-1 1.0.0 --from public.ecr.aws/nginx/nginx:stable-alpine
image_tag      = "1.0.0"
container_port = 80

task_cpu      = 256
task_memory   = 512
desired_count = 1

listener_rule_priority = 100
path_patterns          = ["/*"]
health_check_path      = "/"
log_retention_days     = 7
