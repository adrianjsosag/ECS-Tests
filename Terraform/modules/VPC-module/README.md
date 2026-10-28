# 🌐 AWS VPC (red) – Terraform

Este proyecto crea en AWS la **red privada** sobre la que corre el laboratorio de ECS Fargate.
Usa [Terraform](https://developer.hashicorp.com/terraform), una herramienta que describe la infraestructura en archivos de texto, y el módulo oficial
[`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest).
Así no hay que crear cada pieza de red a mano en la consola de AWS.

Es la **base de toda la plataforma**: el [ALB](../ALB-module/README.md), los [servicios](../ECS-services-module/README.md) y el [Bastion](../EC2-bastion-host-module/README.md) opcional leen sus datos del state de esta VPC.

| 🧭 Ficha rápida | |
|---|---|
| **Paso en el despliegue** | **1** – el primero, después del bucket del state ([guía](../../README.md#guía-de-despliegue-paso-a-paso)) |
| **Depende de** | Bucket del state del ambiente ([`bootstrap`](../../bootstrap/README.md)) |
| **Lo usan** | ALB, servicios ECS y, si lo despliegas, el Bastion (opcional): leen su state |
| **Recursos (`plan`)** | 31 |
| **Tiempo de despliegue** | 3–5 min |
| **Costo principal** | NAT Gateway: por hora y por GB procesado |

> ⚠️ **Antes de desplegar este módulo debe existir el bucket S3 del state del ambiente** ([`bootstrap`](../../bootstrap/README.md), `./bootstrap.sh dev`): su `backend.tf` guarda el state ahí, en el bucket que indica `environments/<env>/backend.hcl`. Si no existe, `terraform init` falla con `NoSuchBucket`.

> 🗺️ Vista general de toda la plataforma: [README de Terraform](../../README.md).

---

## Índice

1. 📦 [¿Qué se crea?](#qué-se-crea)
2. 📚 [Conceptos básicos](#conceptos-básicos)
3. 🗺️ [Diagrama](#diagrama)
4. 🔍 [Cómo funciona](#cómo-funciona)
5. 🔗 [¿De qué depende? (remote state)](#de-qué-depende-remote-state)
6. 📁 [Estructura de archivos](#estructura-de-archivos)
7. 🏷️ [Versiones](#versiones)
8. ⚙️ [Variables](#variables)
9. 📤 [Outputs](#outputs)
10. 🧪 [Cómo probarlo sin crear nada (plan)](#cómo-probarlo-sin-crear-nada-plan)
11. 🚀 [Cómo desplegarlo paso a paso](#cómo-desplegarlo-paso-a-paso)
12. 🔒 [Seguridad](#seguridad)
13. 💰 [Costos](#costos)
14. 🛠️ [Problemas frecuentes](#problemas-frecuentes)

---

## ¿Qué se crea?

Se crea una red aislada en AWS (VPC) repartida en **3 centros de datos distintos** (Availability Zones).
En cada uno hay **3 tipos de subred**: pública, privada y de base de datos, así que en total son **9 subredes**.

| Capa | Cantidad | ¿Tiene Internet? | ¿Para qué se usa? |
|---|---|---|---|
| **Pública** | 3 | Sí, entrada y salida, a través del Internet Gateway | Balanceador de carga (ALB) y el NAT Gateway |
| **Privada** | 3 | Solo salida, a través del NAT Gateway | Contenedores de ECS Fargate (la aplicación) |
| **Database** | 3 | No (totalmente aislada) | Bases de datos RDS / Aurora |

> 💡 **Analogía:** piensa en la VPC como un edificio de oficinas.
> - Las **subredes públicas** son la recepción, abierta a la calle.
> - Las **privadas** son las oficinas: los empleados pueden salir, pero los visitantes no entran directamente.
> - Las de **base de datos** son la bóveda: solo se llega a ella desde dentro del edificio.

---

## Conceptos básicos

| Término | Qué significa en palabras simples |
|---|---|
| **VPC** (Virtual Private Cloud) | Tu propia red privada dentro de AWS, separada de las de otros clientes. |
| **Región** | Ubicación geográfica de AWS, por ejemplo `us-east-1` (Virginia). |
| **Availability Zone (AZ)** | Un centro de datos independiente dentro de una región (`us-east-1a`, `us-east-1b`, ...). Repartir los recursos en varias AZs evita que una falla en un centro de datos tumbe todo. |
| **CIDR** | La forma de escribir un rango de direcciones IP. `10.0.0.0/16` incluye unas 65 000 direcciones; `10.0.1.0/24` incluye 256, de las que AWS reserva 5. Mientras **más grande** es el número después de `/`, **más pequeño** es el rango. |
| **Subnet (subred)** | Un trozo del rango de la VPC que vive en **una sola** AZ. |
| **Internet Gateway (IGW)** | La "puerta principal" de la VPC hacia Internet. |
| **NAT Gateway** | Permite que los recursos privados **salgan** a Internet (por ejemplo, para descargar imágenes de contenedores o actualizaciones) sin que nadie de fuera pueda iniciar una conexión hacia ellos. |
| **Elastic IP** | Una IP pública fija. El NAT Gateway la usa para salir a Internet. |
| **Route table (tabla de rutas)** | Las "señales de tráfico" de cada subred: indican hacia dónde enviar los paquetes. |
| **DB Subnet Group** | Un grupo de subredes que se le entrega a RDS para que sepa en qué subredes puede crear la base de datos. |
| **Módulo de Terraform** | Un paquete reutilizable de código Terraform. Aquí usamos uno de la comunidad que ya sabe crear una VPC completa. |

---

## Diagrama

```mermaid
flowchart TB
    internet((Internet))

    subgraph vpc["VPC 10.0.0.0/16"]
        igw[Internet Gateway]

        subgraph az1["AZ 1 (ej. us-east-1a)"]
            pub1["Pública<br/>10.0.101.0/24"]
            nat[NAT Gateway<br/>+ Elastic IP]
            priv1["Privada<br/>10.0.1.0/24"]
            db1["Database<br/>10.0.151.0/24"]
        end

        subgraph az2["AZ 2 (ej. us-east-1b)"]
            pub2["Pública<br/>10.0.102.0/24"]
            priv2["Privada<br/>10.0.2.0/24"]
            db2["Database<br/>10.0.152.0/24"]
        end

        subgraph az3["AZ 3 (ej. us-east-1c)"]
            pub3["Pública<br/>10.0.103.0/24"]
            priv3["Privada<br/>10.0.3.0/24"]
            db3["Database<br/>10.0.153.0/24"]
        end

        dbsg[["DB Subnet Group"]]
    end

    internet <--> igw
    igw <--> pub1 & pub2 & pub3
    pub1 --- nat
    priv1 & priv2 & priv3 -- "0.0.0.0/0" --> nat
    db1 & db2 & db3 -.-> dbsg
```

👀 **Cómo leerlo:**
- **Columnas:** cada recuadro "AZ" es un centro de datos distinto. Las tres AZs tienen la misma estructura, así que si una falla, las otras dos siguen funcionando.
- **Flechas sólidas:** muestran el tráfico de red.
- **Flecha punteada:** indica que las 3 subredes de base de datos forman parte del DB Subnet Group. No es tráfico.
- **NAT Gateway:** hay uno solo, en la AZ 1, para ahorrar costos. Ver [Costos](#costos).

---

## Cómo funciona

El núcleo del proyecto es [`vpc-module.tf`](manifests/vpc-module.tf): llama al módulo oficial `terraform-aws-modules/vpc/aws` (versión `6.7.3`) con los rangos de [`environments/dev/vpc.tfvars`](../../environments/dev/vpc.tfvars). El módulo crea la VPC, las 9 subredes, el Internet Gateway, el NAT Gateway, las tablas de rutas y el DB Subnet Group. Hay dos comportamientos que conviene entender:

### ¿Cómo viaja el tráfico?

Cada tipo de subred tiene su propia **tabla de rutas**:

| Subred | Regla principal | Qué significa |
|---|---|---|
| **Pública** | `0.0.0.0/0 → Internet Gateway` | Todo lo que no es tráfico interno va directo a Internet. Los recursos reciben una IP pública automáticamente (`map_public_ip_on_launch = true`). |
| **Privada** | `0.0.0.0/0 → NAT Gateway` | Pueden salir a Internet a través del NAT, pero nadie de fuera puede iniciar una conexión hacia ellas. |
| **Database** | Solo la ruta local `10.0.0.0/16` | Únicamente pueden hablar con otros recursos de la VPC. No tienen ningún camino hacia Internet. |

> ℹ️ `0.0.0.0/0` significa "cualquier destino". Todas las subredes tienen además una ruta "local" que les permite comunicarse entre sí dentro de la VPC.

🧭 **Ejemplo de una petición real:**

1. Un usuario abre la aplicación y la petición entra por el **Internet Gateway**.
2. Llega al **balanceador (ALB)** en una subred pública.
3. El ALB la reenvía a un **contenedor de Fargate** en una subred privada.
4. El contenedor consulta la **base de datos** en una subred de database, por la red interna.
5. Si el contenedor necesita descargar algo de Internet, sale por el **NAT Gateway**.

### Availability Zones automáticas

No hace falta escribir a mano qué AZs usar. En `vpc-module.tf` el proyecto **le pregunta a AWS** qué AZs están disponibles en la región:

```hcl
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]   # descarta Local Zones y Wavelength Zones
  }
}
```

Luego, en `local-values.tf`, se decide qué lista usar:

```hcl
azs = length(var.vpc_availability_zones) > 0 ? var.vpc_availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)
```

En palabras: *"si el usuario indicó AZs, usa esas; si no, toma las 3 primeras disponibles"*.

- **Comportamiento por defecto:** `vpc_availability_zones` está vacía, así que se detectan automáticamente. En `us-east-1` normalmente serán `us-east-1a`, `us-east-1b` y `us-east-1c`.
- **Para elegirlas tú:** añade esta línea en `environments/dev/vpc.tfvars` con exactamente 3 AZs:
  ```hcl
  vpc_availability_zones = ["us-east-1a", "us-east-1c", "us-east-1d"]
  ```
- **Ventaja:** si cambias `aws_region`, por ejemplo a `eu-west-1`, no tienes que tocar nada más.

---

## ¿De qué depende? (remote state)

**Solo necesita el [bucket del state](../../bootstrap/README.md)**, donde guarda su state (`VPC-module/terraform.tfstate`): es el primer módulo de la plataforma.

Al revés, varios módulos leen su state (clave `VPC-module/terraform.tfstate` del bucket S3) con `terraform_remote_state`:

| Módulo | Outputs de la VPC que lee |
|---|---|
| [`ALB-module`](../ALB-module/README.md) | `vpc_id`, `public_subnets`, `vpc_cidr_block` |
| [`ECS-services-module`](../ECS-services-module/README.md) | `vpc_id`, `private_subnets` |
| [`EC2-bastion-host-module`](../EC2-bastion-host-module/README.md) *(opcional)* | `vpc_id`, `public_subnets` |

> ℹ️ El [cluster ECS](../ECS-cluster-module/README.md) es solo Fargate y **no** lee la VPC: la red de las tareas la define cada servicio.

> ⚠️ Por eso **no borres** su state del bucket mientras la VPC exista, y destrúyela **la última** (solo el bucket del state va después).

---

## Estructura de archivos

```
modules/VPC-module/
├── README.md                 # Este documento
└── manifests/
    ├── versions.tf           # Versión de Terraform, del provider AWS y la conexión con AWS
    ├── backend.tf            # Dónde se guarda el state: bucket S3, clave VPC-module/terraform.tfstate
    ├── generic-variables.tf  # Variables generales: región, entorno, división
    ├── local-values.tf       # Valores calculados: nombre, etiquetas (tags) y AZs a usar
    ├── vpc-variables.tf      # Variables de la VPC: rangos IP, AZs, NAT, base de datos
    ├── vpc-module.tf         # Consulta de AZs + creación de la VPC con el módulo
    └── vpc-outputs.tf        # Datos que se muestran al terminar (IDs, IPs, ...)
```

> ℹ️ **Los valores no están en el módulo**, sino en el ambiente: generales en [`environments/dev/common.tfvars`](../../environments/dev/common.tfvars) y propios en [`environments/dev/vpc.tfvars`](../../environments/dev/vpc.tfvars). El bucket del backend, en [`environments/dev/backend.hcl`](../../environments/dev/backend.hcl) (ver [Ambientes](../../README.md#ambientes)).

📝 **Notas sobre los archivos:**
- Los archivos `.tf` contienen el código, igual para todos los ambientes. Los **valores** de cada ambiente están en los `.tfvars` de `environments/<env>/`.
- Para cambiar algo en `dev`, por ejemplo los rangos IP, normalmente basta con editar `environments/dev/vpc.tfvars`.
- Terraform lee **todos** los `.tf` de la carpeta y los trata como uno solo. El nombre de cada archivo sirve solo para organizarse; no cambia el resultado.

| Archivo | Explicación |
|---|---|
| [`versions.tf`](manifests/versions.tf) | Define qué versión de Terraform y del *provider* de AWS se necesitan. El *provider* es el plugin que permite a Terraform hablar con AWS. Las credenciales salen de la cadena por defecto de AWS: `AWS_PROFILE`, variables de entorno o el perfil `default` de `~/.aws/credentials`. |
| [`backend.tf`](manifests/backend.tf) | Indica que el state se guarda en el **bucket S3 del ambiente** (lo crea el [`bootstrap`](../../bootstrap/README.md)), con la clave `VPC-module/terraform.tfstate`, cifrado y con bloqueo. El nombre del bucket no está aquí: llega en el `init` desde `environments/<env>/backend.hcl`. |
| [`generic-variables.tf`](manifests/generic-variables.tf) | Declara variables comunes a cualquier proyecto: región, entorno (`dev`, `qa`, `prod`...) y división de negocio. Entorno y división no tienen valor por defecto: llegan desde `common.tfvars`. |
| [`local-values.tf`](manifests/local-values.tf) | Calcula valores a partir de otros: el prefijo del nombre (`CloudEngineering-dev`), las etiquetas comunes y la lista final de AZs. |
| [`vpc-variables.tf`](manifests/vpc-variables.tf) | Declara las variables de la red e incluye **validaciones**. Por ejemplo, Terraform da error si no hay exactamente 3 subredes de cada tipo. |
| [`vpc-module.tf`](manifests/vpc-module.tf) | Es el núcleo del proyecto: pregunta a AWS qué AZs hay disponibles y llama al módulo que crea la VPC, las subredes, los gateways y las tablas de rutas. |
| [`vpc-outputs.tf`](manifests/vpc-outputs.tf) | Lo que Terraform muestra al terminar. El ALB, los servicios ECS y el Bastion (opcional) leen estos datos de su state. |

---

## Versiones

| Componente | Versión | Comentario |
|---|---|---|
| Terraform | `>= 1.16` | Validado con v1.17.0 |
| Provider `hashicorp/aws` | `~> 6.67` | Acepta cualquier 6.x a partir de 6.67, pero no la 7.0 |
| Módulo `terraform-aws-modules/vpc/aws` | `6.7.3` | Versión fija para evitar cambios inesperados |

---

## Variables

Los valores **por defecto** están en los archivos `*-variables.tf`. Los valores **que realmente se usan** en `dev` están en [`environments/dev/common.tfvars`](../../environments/dev/common.tfvars) y [`environments/dev/vpc.tfvars`](../../environments/dev/vpc.tfvars), que se pasan con `-var-file` y tienen prioridad sobre los valores por defecto.

### Generales (`generic-variables.tf`)

| Variable | Tipo | Por defecto | Valor en `dev` (`common.tfvars`) | Descripción |
|---|---|---|---|---|
| `aws_region` | texto | `us-east-1` | `us-east-1` | Región donde se crea todo |
| `environment` | texto | — (obligatoria) | `dev` | Entorno. Se usa en nombres y etiquetas |
| `business_division` | texto | — (obligatoria) | `CloudEngineering` | Área responsable. Se usa en nombres y etiquetas |

### VPC (`vpc-variables.tf`)

| Variable | Tipo | Valor en `dev` | Descripción |
|---|---|---|---|
| `vpc_name` | texto | `my-sr-labs-vpc` | Parte final del nombre de la VPC |
| `vpc_cidr_block` | texto | `10.0.0.0/16` | Rango total de IPs de la VPC |
| `vpc_availability_zones` | lista | `[]` (automático) | AZs a usar. Vacía para autodetectar, o 3 AZs exactas |
| `vpc_public_subnets` | lista | `10.0.101.0/24`, `10.0.102.0/24`, `10.0.103.0/24` | Rangos de las subredes públicas (uno por AZ) |
| `vpc_private_subnets` | lista | `10.0.1.0/24`, `10.0.2.0/24`, `10.0.3.0/24` | Rangos de las subredes privadas (uno por AZ) |
| `vpc_database_subnets` | lista | `10.0.151.0/24`, `10.0.152.0/24`, `10.0.153.0/24` | Rangos de las subredes de base de datos (uno por AZ) |
| `vpc_create_database_subnet_group` | sí/no | `true` | Crea el DB Subnet Group para RDS |
| `vpc_create_database_subnet_route_table` | sí/no | `true` | Da a las subredes de base de datos su propia tabla de rutas, sin Internet |
| `vpc_enable_nat_gateway` | sí/no | `true` | Permite que las subredes privadas salgan a Internet |
| `vpc_single_nat_gateway` | sí/no | `true` | `true` crea un solo NAT (más barato); `false` crea uno por AZ (más resistente) |

✔️ **Reglas que valida Terraform automáticamente:**
- Cada lista de subredes debe tener **exactamente 3** rangos, uno por AZ.
- `vpc_availability_zones` debe estar vacía o tener **exactamente 3** AZs.
- Los rangos de las subredes deben estar **dentro** de `vpc_cidr_block` y **no deben solaparse** entre sí. Esto último lo comprueba AWS al crear los recursos.

### Nombres y etiquetas

- **Nombre de la VPC:** se forma como `<business_division>-<environment>-<vpc_name>`. Con los valores actuales es **`CloudEngineering-dev-my-sr-labs-vpc`**.
- **Etiquetas comunes:** todos los recursos llevan `owners` y `environment`, lo que ayuda a identificar costos y responsables.
- **Etiqueta de las subredes:** cada subred lleva además una etiqueta `Type`, con el valor `Public Subnets`, `Private Subnets` o `Private Database Subnets`.

---

## Outputs

Al terminar `terraform apply`, Terraform muestra estos datos. También puedes verlos después con `terraform output`.

| Output | Descripción | ¿Para qué lo necesitas? |
|---|---|---|
| `vpc_id` | ID de la VPC (`vpc-xxxx`) | ALB, servicios ECS y Bastion: crean sus Security Groups y target groups en ella |
| `vpc_cidr_block` | Rango IP de la VPC | ALB: su regla de salida solo permite tráfico hacia la VPC |
| `public_subnets` | IDs de las 3 subredes públicas | Para el balanceador de carga (ALB) |
| `public_subnets_cidr_blocks` | Rangos IP de las 3 subredes públicas | Informativo (ningún módulo lo lee hoy) |
| `private_subnets` | IDs de las 3 subredes privadas | Para los servicios de ECS Fargate |
| `database_subnets` | IDs de las 3 subredes de base de datos | Para referencia o auditoría |
| `database_subnet_group_name` | Nombre del DB Subnet Group | Para una futura base de datos RDS (ningún módulo lo lee hoy) |
| `nat_public_ips` | IP(s) pública(s) del NAT | Para que un servicio externo permita el tráfico de tu aplicación |
| `azs` | AZs usadas | Para confirmar dónde quedó cada recurso |

---

## Cómo probarlo sin crear nada (plan)

```bash
cd Terraform/modules/VPC-module/manifests
E=~/ECS-Tests/Terraform/environments/dev
terraform init -reconfigure -backend-config=$E/backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=$E/common.tfvars -var-file=$E/vpc.tfvars        # solo consulta en AWS las AZs disponibles; no crea nada
```

La VPC no lee el state de ningún otro módulo, así que el `plan` funciona directamente. Solo necesita credenciales de AWS y el bucket del state (para el `terraform init`). Sin bucket, puedes comprobar el código sin backend con `terraform init -backend=false`, `terraform fmt -check -recursive` y `terraform validate`.

✅ **Resultado verificado** (2026-10-28, Terraform v1.17.0, sin `apply`): `Plan: 31 to add, 0 to change, 0 to destroy.`

---

## Cómo desplegarlo paso a paso

### Requisitos previos

1. **El bucket del state creado** ([`bootstrap`](../../bootstrap/README.md)): es lo primero que se despliega.
2. **Terraform 1.16 o superior.** En este equipo está instalado en WSL; puedes comprobarlo con `terraform version`.
3. **Credenciales de AWS** (perfil `default` o `AWS_PROFILE`). Puedes comprobarlas con:
   ```bash
   aws sts get-caller-identity
   ```
   Si no tienes credenciales configuradas, ejecuta `aws configure`.
4. Permisos en AWS para crear VPC, subredes, gateways, Elastic IPs y tablas de rutas.

### Pasos

Abre una terminal de WSL y ve a la carpeta `manifests/`:

```bash
cd Terraform/modules/VPC-module/manifests
E=~/ECS-Tests/Terraform/environments/dev   # ambiente
```

| # | Comando | Qué hace |
|---|---|---|
| 1 | `terraform init -reconfigure -backend-config=$E/backend.hcl` | Descarga el provider de AWS y el módulo de VPC, y conecta con el state en el bucket del ambiente (`VPC-module/terraform.tfstate`). Se ejecuta una vez, o de nuevo al cambiar versiones (con `-upgrade`). |
| 2 | `terraform fmt` | Ordena el formato del código. Es opcional. |
| 3 | `terraform validate` | Comprueba que el código no tenga errores de sintaxis. |
| 4 | `terraform plan -var-file=$E/common.tfvars -var-file=$E/vpc.tfvars` | **Muestra** lo que se va a crear, sin crear nada todavía. |
| 5 | `terraform apply -var-file=$E/common.tfvars -var-file=$E/vpc.tfvars` | Crea los recursos en AWS. Pide confirmación: escribe `yes`. |
| 6 | `terraform output` | Muestra los outputs. |

🔎 **Qué deberías ver en el `plan`:**
- 1 VPC
- 9 subredes (3 públicas, 3 privadas y 3 de base de datos) repartidas en 3 AZs distintas
- 1 Internet Gateway
- 1 NAT Gateway y 1 Elastic IP
- 3 tablas de rutas (pública, privada y de base de datos), las 9 asociaciones de las subredes y 2 rutas `0.0.0.0/0` (hacia el Internet Gateway y hacia el NAT)
- 1 DB Subnet Group
- 3 recursos "por defecto" que el módulo adopta para dejarlos sin reglas: NACL, tabla de rutas y Security Group por defecto de la VPC

En total, **31 recursos**.

### Eliminar

```bash
E=~/ECS-Tests/Terraform/environments/dev
terraform destroy -var-file=$E/common.tfvars -var-file=$E/vpc.tfvars
```

Pide confirmación (`yes`) y borra **todos** los recursos creados por este proyecto.

> ℹ️ Los archivos `.terraform/` y `.terraform.lock.hcl` se generan automáticamente en `manifests/`.
> - **El state** es la "memoria" de Terraform: registra qué recursos creó. Se guarda en el **bucket S3** (`VPC-module/terraform.tfstate`), no en tu PC. **No lo borres** mientras la infraestructura exista: el ALB y los servicios lo leen.
> - **`.terraform.lock.hcl`** conviene subirlo a git, porque fija las versiones exactas de los providers.

---

## Seguridad

- **Tres capas de red:**
  - Solo las subredes **públicas** tienen ruta directa a Internet.
  - Las **privadas** solo salen por el NAT Gateway: nadie de fuera puede iniciar una conexión hacia ellas.
  - Las de **base de datos** no tienen ningún camino hacia Internet.
- **IP pública automática solo en las subredes públicas** (`map_public_ip_on_launch`). Pon ahí solo lo que deba ser público: el ALB y el NAT.
- **Sin VPC Flow Logs:** hoy no se registra el tráfico de red. Activarlos es una [mejora pendiente](../../README.md#seguridad).
- **Sin VPC Endpoints:** el tráfico hacia ECR, S3 o CloudWatch sale por el NAT Gateway. Ver las mismas mejoras.
- **El state contiene IDs e IPs de la red:** se guarda en el bucket S3 privado y cifrado del [`bootstrap`](../../bootstrap/README.md). No descargues copias a git ni a carpetas sincronizadas.

### Mejoras recomendadas

Hallazgos de la [revisión de buenas prácticas](../../README.md#revisión-y-plan-de-evolución) (2026-10-28) que afectan a este proyecto. El número es el del hallazgo en esa revisión y la fase, la del plan de evolución.

| # | Prioridad | Mejora | Fase |
|---|---|---|---|
| 16 | 🟡 Operación | **VPC endpoints:** gateway de S3 (gratis), `ecr.api`, `ecr.dkr`, `logs` y `ssmmessages`, para que las tareas no salgan por el NAT | 1 |
| 16 | 🟡 Operación | **Un NAT Gateway por AZ** en producción (`vpc_single_nat_gateway = false`): hoy uno solo es un punto único de fallo | 2 |
| 16 | 🟡 Operación | Quitar las subredes de base de datos y el DB subnet group mientras ningún proyecto los use | 2 |
| 15 | 🟡 Operación | **VPC Flow Logs** hacia CloudWatch Logs o S3 | 2 |
| 13 | 🟡 Arquitectura | Publicar `vpc_id` y las subredes en **SSM Parameter Store** para que los demás proyectos no lean el state completo | 1 |

---

## Costos

- **El NAT Gateway es lo único con costo relevante.** Se cobra por cada hora que está encendido y por cada GB que pasa por él. Al terminar el laboratorio ejecuta `terraform destroy`.
- La VPC, las subredes, las tablas de rutas y el Internet Gateway **no tienen costo**.
- **Un NAT o varios:**
  - Con `vpc_single_nat_gateway = true` hay un solo NAT. Si su AZ falla, las subredes privadas de las otras AZs pierden la salida a Internet.
  - En **producción** usa `false` para tener un NAT por AZ: cuesta unas 3 veces más, pero es tolerante a fallos.

---

## Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `Module not installed` | No se ejecutó `terraform init` | Ejecuta `terraform init -reconfigure -backend-config=$E/backend.hcl` |
| `No value for required variable "environment"` | Faltan los `-var-file` del ambiente | Añade `-var-file=$E/common.tfvars -var-file=$E/vpc.tfvars` |
| `NoSuchBucket` / `S3 bucket does not exist` en `terraform init` | Aún no existe el bucket del state, o el `bucket` de `environments/<env>/backend.hcl` no coincide | Ejecuta antes el [`bootstrap`](../../bootstrap/README.md) del ambiente (`./bootstrap.sh dev`) y revisa `environments/<env>/backend.hcl` |
| `No valid credential sources found` | No hay credenciales de AWS | Ejecuta `aws configure` y comprueba el perfil `default` (o `AWS_PROFILE`) |
| `Invalid index` / error en `slice()` | La región tiene menos de 3 AZs disponibles | Usa otra región o define `vpc_availability_zones` manualmente |
| `must contain exactly 3 CIDR blocks` | Alguna lista de subredes no tiene 3 elementos | Revisa `environments/dev/vpc.tfvars` |
| `InvalidSubnet.Conflict` / `InvalidSubnet.Range` | Rangos solapados o fuera de la VPC | Revisa que cada `/24` esté dentro de `10.0.0.0/16` y no se repita |
| `ElasticIP limit exceeded` | La cuenta llegó al límite de Elastic IPs (5 por región) | Libera IPs sin uso o solicita un aumento de cuota |
