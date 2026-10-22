#!/usr/bin/env bash
# Detecta los servicios nuevos o modificados de Terraform/ECS-services-module/services/
# y valida que se puedan desplegar sin pisar el state ni la regla del ALB de otro servicio.
# Lo usa el job "detect" de .github/workflows/terraform-services-cd.yml y se puede ejecutar en local.
#
# Variables de entrada:
#   BASE          Commit base del diff. Vacío o todo ceros = todos los servicios
#   HEAD          Commit final del diff (por defecto HEAD)
#   SERVICES      Lista manual (workflow_dispatch): "all" o "svc1,svc2". Si se indica, no se usa el diff
#   SERVICES_DIR  Carpeta de los servicios (por defecto Terraform/ECS-services-module/services)
#
# Salidas (en $GITHUB_OUTPUT si existe; siempre por pantalla):
#   services      JSON con los servicios a desplegar, p. ej. ["nginx-1"]
#   has_services  true / false
#   deleted       Servicios borrados del repositorio (separados por comas): NO se destruyen
#
# Código de salida: 0 si todo es correcto, 1 si falla una comprobación de seguridad.
set -euo pipefail

SERVICES_DIR="${SERVICES_DIR:-Terraform/ECS-services-module/services}"
BASE="${BASE:-}"
HEAD="${HEAD:-HEAD}"
SERVICES="${SERVICES:-}"
ZERO_SHA="0000000000000000000000000000000000000000"
FAILED=0

err()  { echo "::error::$*"; FAILED=1; }
warn() { echo "::warning::$*"; }

# Todos los servicios que existen hoy (carpetas services/<servicio>/manifests)
all_services() {
  find "$SERVICES_DIR" -mindepth 2 -maxdepth 2 -type d -name manifests 2>/dev/null \
    | awk -F/ '{print $(NF-1)}' | sort -u
}

# 1. Servicios candidatos
if [[ -n "$SERVICES" ]]; then
  if [[ "$SERVICES" == "all" ]]; then
    candidates="$(all_services)"
    reason="ejecución manual: todos los servicios"
  else
    candidates="$(sed -E 's/[, ]+/\n/g' <<<"$SERVICES" | sed '/^$/d' | sort -u)"
    reason="ejecución manual: ${SERVICES}"
  fi
elif [[ -z "$BASE" || "$BASE" == "$ZERO_SHA" ]] || ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  candidates="$(all_services)"
  reason="sin commit base (rama nueva o historial incompleto): todos los servicios"
else
  candidates="$(git diff --name-only "$BASE" "$HEAD" -- "$SERVICES_DIR/" \
    | awk -v dir="$SERVICES_DIR/" 'index($0, dir) == 1 { rest = substr($0, length(dir) + 1); n = split(rest, p, "/"); if (n > 1) print p[1] }' \
    | sort -u)"
  reason="cambios entre ${BASE:0:7} y ${HEAD:0:7}"
fi
echo "==> Servicios candidatos (${reason}): $(echo "$candidates" | paste -sd ' ' -)"

# 2. Desplegar (existe manifests/) o borrado (ya no existe)
deploy=()
deleted=()
for svc in $candidates; do
  if [[ -d "$SERVICES_DIR/$svc/manifests" ]]; then
    deploy+=("$svc")
  elif [[ -n "$SERVICES" ]]; then
    err "El servicio '$svc' no existe en $SERVICES_DIR (disponibles: $(all_services | paste -sd ',' -))"
  else
    deleted+=("$svc")
    warn "El servicio '$svc' se borró del repositorio: el workflow NO lo destruye. Destrúyelo a mano ANTES de borrar su carpeta (terraform destroy en $SERVICES_DIR/$svc/manifests) o con el state en S3."
  fi
done

# 3. Comprobaciones de seguridad de los servicios a desplegar
for svc in "${deploy[@]}"; do
  man="$SERVICES_DIR/$svc/manifests"

  # La key del backend debe ser la de su carpeta (una carpeta copiada pisaría el state de otro servicio)
  want_key="ECS-services-module/services/$svc/terraform.tfstate"
  key="$(sed -nE 's/^[[:space:]]*key[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$man/backend.tf" 2>/dev/null | head -1)"
  if [[ "$key" != "$want_key" ]]; then
    err "$svc: la key de backend.tf es '${key:-<ninguna>}' y debe ser '$want_key' (si no, pisaría el state de otro servicio)"
  fi

  # service_name debe coincidir con la carpeta (nombres de recursos y del servicio ECS)
  name="$(sed -nE 's/^[[:space:]]*service_name[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$man/service.auto.tfvars" 2>/dev/null | head -1)"
  if [[ "$name" != "$svc" ]]; then
    err "$svc: service_name en service.auto.tfvars es '${name:-<ninguno>}' y debe ser '$svc' (el nombre de la carpeta)"
  fi
done

# La prioridad de la regla del ALB debe ser única entre TODOS los servicios
declare -A owner=()
for svc in $(all_services); do
  prio="$(sed -nE 's/^[[:space:]]*listener_rule_priority[[:space:]]*=[[:space:]]*([0-9]+).*/\1/p' "$SERVICES_DIR/$svc/manifests/service.auto.tfvars" 2>/dev/null | head -1)"
  [[ -z "$prio" ]] && continue
  if [[ -n "${owner[$prio]:-}" ]]; then
    err "listener_rule_priority = $prio está repetida en '${owner[$prio]}' y '$svc': cada servicio necesita una prioridad única"
  else
    owner[$prio]="$svc"
  fi
done

# 4. Salidas
json="[]"
if ((${#deploy[@]})); then
  json="[$(printf '"%s",' "${deploy[@]}" | sed 's/,$//')]"
fi
has_services=false
((${#deploy[@]})) && has_services=true
deleted_csv="$(IFS=,; echo "${deleted[*]:-}")"

echo "==> A desplegar: ${json}"
echo "==> Borrados (no se destruyen): ${deleted_csv:-ninguno}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "services=${json}"
    echo "has_services=${has_services}"
    echo "deleted=${deleted_csv}"
  } >> "$GITHUB_OUTPUT"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Servicios detectados"
    echo ""
    echo "Criterio: ${reason}"
    echo ""
    echo "| Servicio | Acción |"
    echo "|---|---|"
    for svc in "${deploy[@]}"; do echo "| \`$svc\` | plan$( [[ "${GITHUB_REF:-}" == refs/heads/main && "${GITHUB_EVENT_NAME:-}" != pull_request ]] && echo ' + apply (con aprobación)') |"; done
    for svc in "${deleted[@]}"; do echo "| \`$svc\` | ⚠️ borrado del repositorio: **no** se destruye |"; done
    ((${#deploy[@]} + ${#deleted[@]})) || echo "| — | Ningún servicio cambió |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if ((FAILED)); then
  echo "==> Comprobaciones de seguridad FALLIDAS: no se despliega nada"
  exit 1
fi
