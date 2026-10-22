# ECR Variables
# One repository per application. Full name: cloudengineering-dev/<key>
repositories = {
  nginx-1 = {} # used by ECS-services-module/services/nginx-1
  nginx-2 = {} # used by ECS-services-module/services/nginx-2

  # Online store (apps/online-store): one repository per image
  web     = {} # frontend/Dockerfile (Next.js)
  api     = {} # backend/Dockerfile --target api (NestJS)
  worker  = {} # backend/Dockerfile --target worker (BullMQ jobs)
  migrate = {} # backend/Dockerfile --target migrate (Prisma migrations, one-off task)
}

ecr_max_image_count      = 10
ecr_untagged_expire_days = 7

# Laboratory: allow terraform destroy to delete repositories with images.
# Production: set to false to protect the images from an accidental destroy.
ecr_force_delete = true
