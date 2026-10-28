#!/usr/bin/env bash
# =============================================================================
# push-image.sh
# Sube una imagen Docker a un repositorio del ECR creado por ECR-module:
#   1. resuelve la URL del repositorio desde el state de Terraform (manifests/)
#   2. valida el tag (no "latest", no repetido: los repositorios son IMMUTABLE)
#   3. hace login en ECR
#   4. construye la imagen (--build) o copia una existente (--from)
#   5. la sube (push) y obtiene su digest (sha256)
#   6. espera el escaneo de vulnerabilidades y muestra el resultado
#   7. imprime cómo usarla en el environments/<env>/services/<servicio>.tfvars de un servicio
#
# Códigos de salida: 0 OK · 1 error de uso/entorno · 3 vulnerabilidades sobre el umbral (--fail-on)
# =============================================================================
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

# --- Colores (solo si la salida es una terminal) -----------------------------
if [[ -t 1 ]]; then
  C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'; C_BLUE=$'\e[34m'; C_BOLD=$'\e[1m'; C_RESET=$'\e[0m'
else
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""; C_RESET=""
fi
info() { printf '%s\n' "${C_BLUE}==>${C_RESET} $*"; }
ok()   { printf '%s\n' "${C_GREEN}OK${C_RESET}  $*"; }
warn() { printf '%s\n' "${C_YELLOW}AVISO${C_RESET} $*" >&2; }
die()  { printf '%s\n' "${C_RED}ERROR${C_RESET} $*" >&2; exit 1; }

usage() {
  cat <<EOF
Uso:
  ${SCRIPT_NAME} <repositorio> <tag> --build <directorio> [--dockerfile <archivo>] [opciones]
  ${SCRIPT_NAME} <repositorio> <tag> --from <imagen-origen> [opciones]

Modos:
  --build <directorio>     Construye la imagen con el Dockerfile de <directorio>
  --dockerfile <archivo>   Dockerfile a usar con --build (por defecto: <directorio>/Dockerfile)
  --target <etapa>         Con --build: etapa (target) del Dockerfile multi-stage a construir
  --build-arg <CLAVE=VALOR> Con --build: argumento de build (se puede repetir)
  --from <imagen>          Copia (mirror) una imagen existente, por ejemplo:
                           public.ecr.aws/nginx/nginx:stable-alpine

Opciones:
  --platform <plataforma>  Plataforma de la imagen (por defecto: linux/amd64, la de Fargate X86_64)
  --fail-on <nivel>        CRITICAL (por defecto) | HIGH | NONE
                           Termina con código 3 si el escaneo encuentra vulnerabilidades
                           de ese nivel o superior (la imagen queda subida igualmente)
  -h, --help               Muestra esta ayuda

Ejemplos:
  ${SCRIPT_NAME} nginx-1 1.0.0 --from public.ecr.aws/nginx/nginx:stable-alpine
  ${SCRIPT_NAME} mi-api 1.2.0 --build ../../mi-api
  ${SCRIPT_NAME} mi-api 1.2.1 --build . --dockerfile docker/Dockerfile.prod --fail-on HIGH
  ${SCRIPT_NAME} mi-api 1.3.0 --build ../../mi-api --target api --build-arg NODE_ENV=production

Repositorios disponibles: ver 'terraform -chdir=${MANIFESTS_DIR} output repository_urls'
EOF
}

# --- Argumentos -----------------------------------------------------------------
REPO=""; TAG=""; BUILD_DIR=""; DOCKERFILE=""; FROM_IMAGE=""; PLATFORM="linux/amd64"; FAIL_ON="CRITICAL"; TARGET=""
BUILD_ARGS=()
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)      [[ $# -ge 2 ]] || die "--build necesita un directorio"; BUILD_DIR="$2"; shift 2 ;;
    --dockerfile) [[ $# -ge 2 ]] || die "--dockerfile necesita un archivo"; DOCKERFILE="$2"; shift 2 ;;
    --target)     [[ $# -ge 2 ]] || die "--target necesita una etapa"; TARGET="$2"; shift 2 ;;
    --build-arg)  [[ $# -ge 2 ]] || die "--build-arg necesita CLAVE=VALOR"; BUILD_ARGS+=("$2"); shift 2 ;;
    --from)       [[ $# -ge 2 ]] || die "--from necesita una imagen"; FROM_IMAGE="$2"; shift 2 ;;
    --platform)   [[ $# -ge 2 ]] || die "--platform necesita un valor"; PLATFORM="$2"; shift 2 ;;
    --fail-on)    [[ $# -ge 2 ]] || die "--fail-on necesita un valor"; FAIL_ON="$(tr '[:lower:]' '[:upper:]' <<<"$2")"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           usage >&2; die "Opción no reconocida: $1" ;;
    *)            POSITIONAL+=("$1"); shift ;;
  esac
done
[[ ${#POSITIONAL[@]} -eq 2 ]] || { usage >&2; die "Se necesitan exactamente 2 argumentos: <repositorio> <tag>"; }
REPO="${POSITIONAL[0]}"; TAG="${POSITIONAL[1]}"

if [[ -n "$BUILD_DIR" && -n "$FROM_IMAGE" ]] || [[ -z "$BUILD_DIR" && -z "$FROM_IMAGE" ]]; then
  die "Indica exactamente un modo: --build <directorio> o --from <imagen>"
fi
[[ -z "$DOCKERFILE" || -n "$BUILD_DIR" ]] || die "--dockerfile solo se usa con --build"
[[ -z "$TARGET" || -n "$BUILD_DIR" ]] || die "--target solo se usa con --build"
[[ ${#BUILD_ARGS[@]} -eq 0 || -n "$BUILD_DIR" ]] || die "--build-arg solo se usa con --build"
[[ -z "$TARGET" || "$TARGET" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "Target inválido: '$TARGET'"
for arg in "${BUILD_ARGS[@]}"; do
  [[ "$arg" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]] || die "--build-arg inválido: '$arg' (formato CLAVE=VALOR)"
done
case "$FAIL_ON" in CRITICAL|HIGH|NONE) ;; *) die "--fail-on debe ser CRITICAL, HIGH o NONE" ;; esac

# Tag: formato válido de Docker y nunca "latest" (los repositorios son IMMUTABLE y "latest" no identifica una versión)
[[ "$TAG" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]{0,127}$ ]] || die "Tag inválido: '$TAG' (letras, números, '.', '_', '-'; máx. 128)"
[[ "$TAG" != "latest" ]] || die "No se permite el tag 'latest': usa una versión, por ejemplo 1.0.0"

if [[ -n "$BUILD_DIR" ]]; then
  [[ -d "$BUILD_DIR" ]] || die "No existe el directorio de build: $BUILD_DIR"
  DOCKERFILE="${DOCKERFILE:-$BUILD_DIR/Dockerfile}"
  [[ -f "$DOCKERFILE" ]] || die "No existe el Dockerfile: $DOCKERFILE"
fi

# --- 1. Herramientas y state de ECR --------------------------------------------------
for cmd in aws docker terraform; do
  command -v "$cmd" >/dev/null 2>&1 || die "Falta la herramienta '$cmd' en el PATH"
done
docker info >/dev/null 2>&1 || die "Docker no responde. ¿Está iniciado Docker (o Docker Desktop con integración WSL)?"
[[ -d "$MANIFESTS_DIR/.terraform" ]] || die "ECR-module no está inicializado: ejecuta 'terraform init -backend-config=../../../environments/<env>/backend.hcl' en $MANIFESTS_DIR (y 'terraform apply' si aún no existe)"

info "Leyendo los repositorios del state de Terraform (S3)"
REGISTRY="$(terraform -chdir="$MANIFESTS_DIR" output -raw registry_url 2>/dev/null)" \
  || die "No se pudo leer el output registry_url: ¿está aplicado ECR-module? (terraform apply en $MANIFESTS_DIR)"
# With an empty state "terraform output -raw" exits 0 and prints nothing
[[ -n "$REGISTRY" ]] || die "No se pudo leer el output registry_url: ¿está aplicado ECR-module? (terraform apply en $MANIFESTS_DIR)"
NAMES_JSON="$(terraform -chdir="$MANIFESTS_DIR" output -json repository_names 2>/dev/null | tr -d ' \n')" || die "No se pudo leer el output repository_names"
REPO_NAME="$(grep -oE "\"${REPO//./\\.}\":\"[^\"]+\"" <<<"$NAMES_JSON" | cut -d'"' -f4 || true)"
if [[ -z "$REPO_NAME" ]]; then
  AVAILABLE="$(grep -oE '"[^"]+":' <<<"$NAMES_JSON" | tr -d '":' | paste -sd ',' - | sed 's/,/, /g')"
  die "El repositorio '$REPO' no existe en ECR-module. Disponibles: ${AVAILABLE:-ninguno}. Añádelo a environments/<env>/ecr.tfvars y aplica ECR-module."
fi
REGION="$(cut -d. -f4 <<<"$REGISTRY")"
IMAGE_URI="${REGISTRY}/${REPO_NAME}"
ok "Repositorio: ${C_BOLD}${IMAGE_URI}${C_RESET} (región ${REGION})"

# --- 2. El tag no debe existir (repositorio IMMUTABLE) --------------------------------
if aws ecr describe-images --region "$REGION" --repository-name "$REPO_NAME" --image-ids imageTag="$TAG" >/dev/null 2>&1; then
  die "El tag '$TAG' ya existe en $REPO_NAME y el repositorio es IMMUTABLE. Usa una versión nueva (por ejemplo, incrementa el número)."
fi

# --- 3. Login en ECR --------------------------------------------------------------------
info "Login en ECR ($REGISTRY)"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY" >/dev/null
ok "Login correcto"

# --- 4. Construir o copiar la imagen ---------------------------------------------------
if [[ -n "$BUILD_DIR" ]]; then
  BUILD_OPTS=()
  [[ -n "$TARGET" ]] && BUILD_OPTS+=(--target "$TARGET")
  for arg in "${BUILD_ARGS[@]}"; do BUILD_OPTS+=(--build-arg "$arg"); done
  info "Construyendo la imagen ($PLATFORM${TARGET:+, target $TARGET}) desde $BUILD_DIR"
  docker build --platform "$PLATFORM" "${BUILD_OPTS[@]}" -f "$DOCKERFILE" -t "${IMAGE_URI}:${TAG}" "$BUILD_DIR"
else
  info "Copiando la imagen $FROM_IMAGE ($PLATFORM)"
  docker pull --platform "$PLATFORM" "$FROM_IMAGE"
  docker tag "$FROM_IMAGE" "${IMAGE_URI}:${TAG}"
fi

# --- 5. Subir y obtener el digest ------------------------------------------------------------
info "Subiendo ${IMAGE_URI}:${TAG}"
docker push "${IMAGE_URI}:${TAG}"
DIGEST="$(aws ecr describe-images --region "$REGION" --repository-name "$REPO_NAME" --image-ids imageTag="$TAG" \
  --query 'imageDetails[0].imageDigest' --output text)"
ok "Imagen subida. Digest: ${C_BOLD}${DIGEST}${C_RESET}"

# --- 6. Escaneo de vulnerabilidades ---------------------------------------------------
EXIT_CODE=0
info "Esperando el resultado del escaneo de vulnerabilidades (scan on push)"
if aws ecr wait image-scan-complete --region "$REGION" --repository-name "$REPO_NAME" --image-id imageTag="$TAG" 2>/dev/null; then
  printf '  %-15s %s\n' "SEVERIDAD" "HALLAZGOS"
  declare -A COUNTS=()
  for sev in CRITICAL HIGH MEDIUM LOW INFORMATIONAL UNDEFINED; do
    n="$(aws ecr describe-image-scan-findings --region "$REGION" --repository-name "$REPO_NAME" --image-id imageTag="$TAG" \
      --query "imageScanFindings.findingSeverityCounts.${sev}" --output text 2>/dev/null || echo None)"
    [[ "$n" == "None" || -z "$n" ]] && n=0
    COUNTS[$sev]=$n
    color=$C_GREEN; [[ $n -gt 0 && ( $sev == CRITICAL || $sev == HIGH ) ]] && color=$C_RED
    printf '  %-15s %s\n' "$sev" "${color}${n}${C_RESET}"
  done
  BLOCKING=0
  case "$FAIL_ON" in
    CRITICAL) BLOCKING=${COUNTS[CRITICAL]} ;;
    HIGH)     BLOCKING=$(( COUNTS[CRITICAL] + COUNTS[HIGH] )) ;;
    NONE)     BLOCKING=0 ;;
  esac
  if [[ $BLOCKING -gt 0 ]]; then
    warn "Hay $BLOCKING vulnerabilidades de nivel $FAIL_ON o superior. La imagen está subida, pero NO se recomienda desplegarla."
    warn "Detalle: aws ecr describe-image-scan-findings --repository-name $REPO_NAME --image-id imageTag=$TAG"
    EXIT_CODE=3
  else
    ok "Escaneo sin vulnerabilidades de nivel $FAIL_ON o superior"
  fi
else
  STATUS="$(aws ecr describe-image-scan-findings --region "$REGION" --repository-name "$REPO_NAME" --image-id imageTag="$TAG" \
    --query 'imageScanStatus.[status,description]' --output text 2>/dev/null || echo 'DESCONOCIDO')"
  warn "No se pudo completar el escaneo ($STATUS). Revísalo en la consola de ECR antes de desplegar."
fi

# --- 7. Cómo usarla -------------------------------------------------------------------
echo
printf '%s\n' "${C_BOLD}Imagen publicada${C_RESET}"
printf '  %-10s %s\n' "Por tag:" "${IMAGE_URI}:${TAG}"
printf '  %-10s %s\n' "Por digest:" "${IMAGE_URI}@${DIGEST}"
echo
printf '%s\n' "${C_BOLD}Úsala en environments/<env>/services/<servicio>.tfvars:${C_RESET}"
printf '  ecr_repository = "%s"\n' "$REPO"
printf '  image_tag      = "%s"\n' "$TAG"
echo "  (el servicio la despliega fijada por su digest; luego: terraform apply -var-file=.../common.tfvars -var-file=.../services/<servicio>.tfvars)"
exit $EXIT_CODE
