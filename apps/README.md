# 📦 Aplicaciones

Aquí van las aplicaciones que se despliegan en la plataforma ECS Fargate de [`Terraform/`](../Terraform/README.md): **una subcarpeta por app**, con su `Dockerfile`.

```text
apps/
└── <app>/
    ├── Dockerfile
    └── ...
```

## Llevar una app a ECS

1. **Repositorio ECR:** añade `<app> = {}` a `repositories` en [`Terraform/environments/dev/ecr.tfvars`](../Terraform/environments/dev/ecr.tfvars) y aplica [`ECR-module`](../Terraform/modules/ECR-module/README.md).
2. **Subir la imagen** (WSL Ubuntu):
   ```bash
   cd ~/ECS-Tests/Terraform/modules/ECR-module
   ./push-image.sh <app> 1.0.0 --build ../../../apps/<app>
   ```
   Los repositorios son **IMMUTABLE**: cada versión necesita un tag nuevo (`latest` no se admite).
3. **Desplegarla:** crea su servicio ECS siguiendo [Añadir otro servicio](../Terraform/modules/ECS-services-module/README.md#añadir-otro-servicio), con `ecr_repository = "<app>"` y el tag que subiste.
