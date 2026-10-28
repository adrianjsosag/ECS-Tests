#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh
# Crea (o actualiza) el bucket S3 de los states de Terraform de un ambiente y
# guarda el state del propio bootstrap DENTRO de ese bucket:
#   1. lee environments/<ambiente>/backend.hcl, common.tfvars y bootstrap.tfvars
#   2. comprueba que el bucket de backend.hcl es el que va a crear el bootstrap
#   3. primera vez (el bucket no existe): apply con un backend LOCAL temporal y
#      después migra el state al bucket (terraform init -migrate-state)
#   4. siguientes veces: init con backend.hcl + apply (el state ya está en S3)
#
# Códigos de salida: 0 OK · 1 error de uso/entorno o apply cancelado
# =============================================================================
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"
ENVIRONMENTS_DIR="$(cd "${SCRIPT_DIR}/../environments" && pwd)"
OVERRIDE_FILE="${MANIFESTS_DIR}/backend_override.tf"

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
  ${SCRIPT_NAME} <ambiente>

Crea el bucket S3 de los states del ambiente (environments/<ambiente>/) y guarda
en él el state del bootstrap (clave bootstrap/terraform.tfstate).
Se puede volver a ejecutar: si el bucket ya existe, solo aplica los cambios.

Ejemplo:
  ${SCRIPT_NAME} dev

Ambientes disponibles: $(ls "$ENVIRONMENTS_DIR" | paste -sd ' ' -)
EOF
}

# Value of a "key = \"value\"" line of an .hcl / .tfvars file
read_value() {
  sed -nE "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$1" | head -1
}

# --- Argumentos -----------------------------------------------------------------
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "")        usage >&2; die "Falta el ambiente, por ejemplo: ${SCRIPT_NAME} dev" ;;
esac
[[ $# -eq 1 ]] || { usage >&2; die "Se necesita exactamente 1 argumento: <ambiente>"; }
ENV_NAME="$1"
ENV_DIR="${ENVIRONMENTS_DIR}/${ENV_NAME}"
[[ -d "$ENV_DIR" ]] || die "No existe el ambiente '${ENV_NAME}' (${ENV_DIR})"
for f in backend.hcl common.tfvars bootstrap.tfvars; do
  [[ -f "$ENV_DIR/$f" ]] || die "Falta ${ENV_DIR}/$f"
done
VAR_FILES=(-var-file="$ENV_DIR/common.tfvars" -var-file="$ENV_DIR/bootstrap.tfvars")

# --- 1. Herramientas y credenciales --------------------------------------------------
for cmd in aws terraform; do
  command -v "$cmd" >/dev/null 2>&1 || die "Falta la herramienta '$cmd' en el PATH"
done
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" \
  || die "No hay credenciales de AWS válidas (aws sts get-caller-identity)"

# --- 2. El bucket de backend.hcl debe ser el que crea el bootstrap ----------------------
BUCKET="$(read_value "$ENV_DIR/backend.hcl" bucket)"
[[ -n "$BUCKET" ]] || die "No se encontró 'bucket' en ${ENV_DIR}/backend.hcl"
ENVIRONMENT="$(read_value "$ENV_DIR/common.tfvars" environment)"
DIVISION="$(read_value "$ENV_DIR/common.tfvars" business_division)"
[[ "$ENVIRONMENT" == "$ENV_NAME" ]] \
  || die "environment = \"${ENVIRONMENT}\" en common.tfvars no coincide con la carpeta '${ENV_NAME}'"
# Same formula as local.state_bucket (manifests/local-values.tf)
EXPECTED_BUCKET="$(tr '[:upper:]' '[:lower:]' <<<"${DIVISION}-${ENVIRONMENT}")-tfstate-${ACCOUNT_ID}"
[[ "$BUCKET" == "$EXPECTED_BUCKET" ]] \
  || die "backend.hcl usa el bucket '${BUCKET}', pero el bootstrap crearía '${EXPECTED_BUCKET}' (cuenta ${ACCOUNT_ID}). Corrige ${ENV_DIR}/backend.hcl"
info "Ambiente ${C_BOLD}${ENV_NAME}${C_RESET} · cuenta ${ACCOUNT_ID} · bucket ${BUCKET}"

# --- 3. Primera vez: apply con backend local y migración del state al bucket ------------
# Also resumes a previous run that stopped before the migration (local state still present)
if [[ -f "$MANIFESTS_DIR/terraform.tfstate" ]] || ! aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  [[ -f "$MANIFESTS_DIR/terraform.tfstate" ]] \
    && warn "Hay un state local de un intento anterior: se continúa desde él" \
    || info "El bucket no existe: primer apply con un backend local temporal"

  trap 'rm -f "$OVERRIDE_FILE"' EXIT
  cat > "$OVERRIDE_FILE" <<'TF'
# TEMPORARY (bootstrap.sh): local backend until the bucket exists. Deleted by the script.
terraform {
  backend "local" {}
}
TF
  terraform -chdir="$MANIFESTS_DIR" init -reconfigure -input=false
  terraform -chdir="$MANIFESTS_DIR" apply "${VAR_FILES[@]}" \
    || die "El apply no terminó. El state local queda en ${MANIFESTS_DIR}/terraform.tfstate: vuelve a ejecutar ${SCRIPT_NAME} ${ENV_NAME}"

  CREATED="$(terraform -chdir="$MANIFESTS_DIR" output -raw state_bucket 2>/dev/null || true)"
  [[ "$CREATED" == "$BUCKET" ]] \
    || die "El apply se canceló o no creó el bucket '${BUCKET}' (output: '${CREATED:-vacío}'). Vuelve a ejecutar ${SCRIPT_NAME} ${ENV_NAME}"
  ok "Bucket creado: ${BUCKET}"

  info "Migrando el state del bootstrap al bucket (bootstrap/terraform.tfstate)"
  rm -f "$OVERRIDE_FILE"
  terraform -chdir="$MANIFESTS_DIR" init -migrate-state -force-copy -input=false -backend-config="$ENV_DIR/backend.hcl"
  aws s3api head-object --bucket "$BUCKET" --key bootstrap/terraform.tfstate >/dev/null \
    || die "No se encontró bootstrap/terraform.tfstate en el bucket: NO se borra el state local"
  rm -f "$MANIFESTS_DIR/terraform.tfstate" "$MANIFESTS_DIR/terraform.tfstate.backup"
  ok "State migrado a s3://${BUCKET}/bootstrap/terraform.tfstate (state local borrado)"

# --- 4. Siguientes veces: el state ya está en el bucket ---------------------------------
else
  info "El bucket ya existe: init con ${ENV_DIR}/backend.hcl y apply"
  terraform -chdir="$MANIFESTS_DIR" init -reconfigure -input=false -backend-config="$ENV_DIR/backend.hcl"
  terraform -chdir="$MANIFESTS_DIR" apply "${VAR_FILES[@]}"
fi

echo
printf '%s\n' "${C_BOLD}Siguiente paso:${C_RESET} desplegar los proyectos del ambiente con"
echo "  terraform init -reconfigure -backend-config=${ENV_DIR}/backend.hcl"
echo "  terraform apply -var-file=${ENV_DIR}/common.tfvars -var-file=${ENV_DIR}/<proyecto>.tfvars"
