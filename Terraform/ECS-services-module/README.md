# 🧩 Servicios ECS (Fargate) – Terraform

Este proyecto despliega **tus aplicaciones** en el [cluster ECS](../ECS-cluster-module/README.md), detrás del [ALB](../ALB-module/README.md). Hay **un directorio y un state por servicio** (`services/<nombre>/manifests/`).

Hoy contiene un solo servicio de prueba: **`nginx-1`**, un nginx oficial copiado al [ECR](../ECR-module/README.md), que responde en `http://<dns del ALB>/`.

| 🧭 Ficha rápida | |
|---|---|
| **Paso en el despliegue** | **5** – el último ([guía](../README.md#guía-de-despliegue-paso-a-paso)) |
| **Depende de** | Bucket del state, [`VPC-module`](../VPC-module/README.md), [`ALB-module`](../ALB-module/README.md), [`ECS-cluster-module`](../ECS-cluster-module/README.md) y [`ECR-module`](../ECR-module/README.md) **con la imagen ya subida** |
| **Lo usan** | Nadie: es la capa final |
| **Recursos (`plan`)** | 10 por servicio |
| **Tiempo de despliegue** | 2–4 min (el `apply` espera a que la tarea esté sana) |
| **Costo principal** | La tarea Fargate (0,25 vCPU / 0,5 GB): ~9 USD/mes con 1 tarea 24/7 |

---

## Índice

1. 📦 [¿Qué se crea?](#qué-se-crea)
2. 🗺️ [Diagrama](#diagrama)
3. 🔗 [¿De qué depende? (remote state)](#de-qué-depende-remote-state)
4. 📁 [Estructura de archivos](#estructura-de-archivos)
5. 🏷️ [Versiones](#versiones)
6. ⚙️ [Variables](#variables)
7. 📤 [Outputs](#outputs)
8. 🧪 [Cómo probarlo sin crear nada (plan)](#cómo-probarlo-sin-crear-nada-plan)
9. 🚀 [Cómo desplegarlo paso a paso](#cómo-desplegarlo-paso-a-paso)
10. ➕ [Añadir otro servicio](#añadir-otro-servicio)
11. 🔒 [Seguridad](#seguridad)
12. 🛠️ [Problemas frecuentes](#problemas-frecuentes)

---

## ¿Qué se crea?

Todo en [`ecs-service.tf`](services/nginx-1/manifests/ecs-service.tf):

| Recurso | Nombre (nginx-1) | ¿Para qué sirve? |
|---|---|---|
| `aws_iam_role` + `aws_iam_role_policy_attachment` | `CloudEngineering-dev-nginx-1-exec` | **Rol de ejecución**: ECS lo usa para descargar la imagen del ECR y escribir los logs (`AmazonECSTaskExecutionRolePolicy`) |
| `aws_cloudwatch_log_group` | `/ecs/CloudEngineering-dev-ecs-cluster/nginx-1` | Logs del contenedor (7 días) |
| `aws_security_group` + regla de entrada + regla de salida | `CloudEngineering-dev-nginx-1-tasks-sg` | Solo el **Security Group del ALB** llega al puerto 80 de las tareas. Salida libre (ECR y logs, por el NAT) |
| `aws_lb_target_group` | `CloudEngineering-dev-nginx-1-tg` | Tipo `ip` (Fargate/`awsvpc`). Health check `GET /` |
| `aws_lb_listener_rule` | prioridad `100`, ruta `/*` | Envía al servicio las peticiones del listener HTTP :80 del ALB |
| `aws_ecs_task_definition` | familia `CloudEngineering-dev-nginx-1` | 1 contenedor, Fargate, 256 CPU / 512 MiB, `X86_64`. La imagen va **fijada por digest** |
| `aws_ecs_service` | `nginx-1` | 1 tarea en `FARGATE`, subredes **privadas**, sin IP pública, *circuit breaker* con rollback |

> ℹ️ La imagen se resuelve con el data source `aws_ecr_image` a partir de `ecr_repository` + `image_tag`. Si el tag no está subido, el `plan` falla antes de crear nada.

---

## Diagrama

```mermaid
flowchart LR
    user(("Internet")) -- "HTTP :80" --> alb["ALB<br/>listener :80"]
    alb -- "regla /* (prioridad 100)" --> tg["Target group<br/>tipo ip"]
    tg --> task["Tarea Fargate nginx-1<br/>subred privada · SG solo desde el ALB"]
    task -- "imagen por digest (vía NAT)" --> ecr[("ECR<br/>cloudengineering-dev/nginx-1")]
    task -- "logs" --> cw[("CloudWatch Logs")]
    svc["Servicio ECS nginx-1"] -. "mantiene 1 tarea" .-> task
```

---

## ¿De qué depende? (remote state)

Guarda su state en `ECS-services-module/services/nginx-1/terraform.tfstate` del [bucket S3](../S3-tfstate-backend-module/README.md) y lee:

| State | Outputs que usa |
|---|---|
| `VPC-module` | `vpc_id`, `private_subnets` |
| `ALB-module` | `http_listener_arn`, `alb_security_group_id`, `alb_url` |
| `ECS-cluster-module` | `cluster_arn`, `cluster_name` |
| `ECR-module` | `repository_urls`, `repository_names` |

---

## Estructura de archivos

```
ECS-services-module/
├── README.md
└── services/
    └── nginx-1/
        └── manifests/
            ├── versions.tf                 # Terraform + provider aws
            ├── backend.tf                  # State en S3 (clave ECS-services-module/services/nginx-1/terraform.tfstate)
            ├── generic-variables.tf        # región, entorno, división
            ├── terraform.tfvars            # us-east-1 / dev / CloudEngineering
            ├── local-values.tf             # nombres, etiquetas e imagen por digest
            ├── remote-state-datasource.tf  # states de VPC, ALB, cluster y ECR + imagen del ECR
            ├── service-variables.tf        # variables del servicio
            ├── service.auto.tfvars         # valores de nginx-1
            ├── ecs-service.tf              # IAM, logs, SG, target group, regla del ALB, task definition, servicio
            └── service-outputs.tf          # outputs
```

---

## Versiones

| Componente | Versión | Comentario |
|---|---|---|
| Terraform | `>= 1.16` | Validado con v1.17.0 |
| Provider `hashicorp/aws` | `~> 6.67` | Validado con 6.70.0 (sin `.terraform.lock.hcl` en el repositorio) |
| Módulos externos | — | Solo recursos nativos de AWS |

---

## Variables

Valores en [`service.auto.tfvars`](services/nginx-1/manifests/service.auto.tfvars):

| Variable | Valor (nginx-1) | Descripción |
|---|---|---|
| `aws_region` / `environment` / `business_division` | `us-east-1` / `dev` / `CloudEngineering` | Generales ([`terraform.tfvars`](services/nginx-1/manifests/terraform.tfvars)); deben coincidir con los otros módulos |
| `service_name` | `nginx-1` | Nombre del servicio y del contenedor (minúsculas, números y `-`; máx. 31 caracteres) |
| `ecr_repository` | `nginx-1` | Repositorio (clave de `repositories` en ECR-module) |
| `image_tag` | `1.0.0` | Tag subido con `push-image.sh`. **`latest` no se admite** (validación) |
| `container_port` | `80` | Puerto del contenedor y del target group |
| `task_cpu` / `task_memory` | `256` / `512` | Tamaño de la tarea (combinación válida de Fargate) |
| `desired_count` | `1` | Tareas en ejecución |
| `listener_rule_priority` | `100` | Prioridad de la regla (única por listener) |
| `path_patterns` | `["/*"]` | Rutas que van a este servicio |
| `health_check_path` | `/` | Ruta del health check del ALB |
| `log_retention_days` | `7` | Retención de los logs |
| `state_bucket` | `null` | Bucket de los states (por defecto se calcula como en S3-tfstate-backend-module) |
| `remote_state_local_dir` | `null` | Solo pruebas: states locales en lugar de S3 |

---

## Outputs

| Output | Descripción |
|---|---|
| `service_url` | URL del ALB (`http://<dns>`) |
| `service_name` | Nombre del servicio ECS |
| `image` | Imagen desplegada (`…/nginx-1@sha256:…`) |
| `task_definition_arn` | Revisión de la task definition |
| `target_group_arn` | Target group del ALB |
| `tasks_security_group_id` | Security Group de las tareas |
| `log_group_name` | Log group de los contenedores |

---

## Cómo probarlo sin crear nada (plan)

Con todos los módulos anteriores aplicados y la imagen subida, basta con `terraform init && terraform plan`.

Sin desplegar nada, se puede probar con states **ficticios** de VPC, ALB, cluster y ECR (`VPC-module.tfstate`, `ALB-module.tfstate`, `ECS-cluster-module.tfstate`, `ECR-module.tfstate` con los outputs de la tabla de [remote state](#de-qué-depende-remote-state)) y un `backend_override.tf` local. Ver [cómo hacerlo](../README.md#probar-sin-crear-nada):

```bash
terraform plan -var remote_state_local_dir=/ruta/a/states-ficticios
```

✅ **Resultado verificado** (Terraform v1.17.0, provider AWS 6.70.0, sin `apply`):

| Prueba | Resultado |
|---|---|
| `fmt -check` y `validate` | Correctos |
| `plan` con states ficticios y la imagen **sin subir** | Falla con `reading ECR Images: couldn't find resource` (esperado: el servicio exige la imagen en ECR) |
| `plan` con states ficticios y un digest simulado | `Plan: 10 to add, 0 to change, 0 to destroy.` |
| `-var image_tag=latest` | Falla con la validación de `image_tag` |

---

## Cómo desplegarlo paso a paso

### Requisitos previos

1. Aplicados, en este orden: [`S3-tfstate-backend-module`](../S3-tfstate-backend-module/README.md), [`VPC-module`](../VPC-module/README.md), [`ALB-module`](../ALB-module/README.md), [`ECS-cluster-module`](../ECS-cluster-module/README.md) y [`ECR-module`](../ECR-module/README.md).
2. La imagen subida al ECR:
   ```bash
   cd ~/ECS-Tests/Terraform/ECR-module
   ./push-image.sh nginx-1 1.0.0 --from public.ecr.aws/nginx/nginx:stable-alpine
   ```

### Pasos

```bash
cd ~/ECS-Tests/Terraform/ECS-services-module/services/nginx-1/manifests
terraform init
terraform plan          # Plan: 10 to add
terraform apply         # espera a que la tarea esté sana (wait_for_steady_state)
curl -i "$(terraform output -raw service_url)/"   # HTTP/1.1 200 OK + "Welcome to nginx!"
```

### Eliminar

```bash
terraform destroy
```

Destruye el servicio **antes** que el cluster, el ALB y la VPC.

---

## Añadir otro servicio

1. Copia `services/nginx-1/` a `services/<nuevo>/`.
2. En `backend.tf` cambia la `key` a `ECS-services-module/services/<nuevo>/terraform.tfstate` (**obligatorio**: si no, pisaría el state de nginx-1).
3. En `service.auto.tfvars` cambia `service_name`, `ecr_repository`, `image_tag`, `listener_rule_priority` (única) y `path_patterns` (por ejemplo `["/nuevo/*"]` con prioridad menor que 100, para que se evalúe antes que `/*`).
4. Sube su imagen con `push-image.sh` y ejecuta `terraform init && terraform apply`.

---

## Seguridad

- Las tareas están en **subredes privadas**, sin IP pública; solo el SG del ALB llega al puerto del contenedor.
- La imagen se despliega **por digest**: no puede cambiar aunque alguien vuelva a usar el tag (además los repos son IMMUTABLE).
- El rol de ejecución solo tiene la política gestionada `AmazonECSTaskExecutionRolePolicy`. No hay *task role* (la app no llama a AWS).
- Pendiente: HTTPS (certificado ACM + listener 443 en el ALB), y restringir `alb_allowed_cidrs`.

---

## Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `couldn't find resource` en `data.aws_ecr_image.this` | El tag no está subido al repositorio | `./push-image.sh nginx-1 1.0.0 --from public.ecr.aws/nginx/nginx:stable-alpine` |
| `Unable to find remote state` | Falta aplicar VPC, ALB, cluster o ECR, o el bucket de `backend.tf` no es el de tu cuenta | Aplica los módulos en orden; revisa `state_bucket` |
| `PriorityInUse` al crear la regla | Otro servicio usa la misma `listener_rule_priority` | Usa una prioridad única |
| El `apply` se queda esperando y termina con rollback del *circuit breaker* | La tarea no pasa el health check o no arranca | `aws logs tail /ecs/CloudEngineering-dev-ecs-cluster/nginx-1` y `aws ecs describe-services --cluster CloudEngineering-dev-ecs-cluster --services nginx-1` |
| `CannotPullContainerError` | La tarea no tiene salida a Internet | Comprueba el NAT Gateway de la VPC |
| `curl` devuelve **404** "no hay ningun servicio en esta ruta" | La regla no coincide o el servicio no está desplegado | Revisa `path_patterns` y que el `apply` haya terminado |
| `curl` devuelve **503** | No hay tareas sanas en el target group | Espera 1–2 min o revisa los logs |
