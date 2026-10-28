# ECR Variables - environment "dev" (ECR-module)
# One repository per application. Full name: cloudengineering-dev/<key>
repositories = {
  nginx-1 = {} # used by modules/ECS-services-module/services/nginx-1
}

ecr_max_image_count      = 10
ecr_untagged_expire_days = 7

# Laboratory: allow terraform destroy to delete repositories with images.
# Production: set to false to protect the images from an accidental destroy.
ecr_force_delete = true
