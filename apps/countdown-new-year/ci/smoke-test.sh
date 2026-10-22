#!/usr/bin/env bash
# Smoke test de la imagen de countdown-new-year.
# Lo usa el job "test" de .github/workflows/countdown-new-year-ci.yml y se puede ejecutar en local.
#
# Uso: smoke-test.sh [url-base] [contenedor]
#   url-base    Por defecto http://localhost:3000
#   contenedor  Nombre del contenedor Docker para comprobar su HEALTHCHECK (opcional)
#
# Código de salida: 0 si todo responde bien, 1 si algo falla.
set -euo pipefail

BASE_URL="${1:-http://localhost:3000}"
CONTAINER="${2:-}"
STARTUP_TIMEOUT=60   # segundos para que la app empiece a responder
HEALTH_TIMEOUT=90    # segundos para el HEALTHCHECK de Docker (el primer chequeo es a los 30 s)
FAILED=0

pass() { printf 'OK     %s\n' "$*"; }
fail() { printf 'FALLO  %s\n' "$*"; FAILED=1; }

# check <descripción> <ruta> <código HTTP esperado> [texto esperado en la respuesta]
check() {
  local desc="$1" path="$2" want_code="$3" want_body="${4:-}" body code
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' "${BASE_URL}${path}" 2>/dev/null || true)"
  if [[ "$code" != "$want_code" ]]; then
    fail "$desc: GET $path -> HTTP ${code:-sin respuesta} (esperado $want_code)"
  elif [[ -n "$want_body" ]] && ! grep -qiF -- "$want_body" "$body"; then
    fail "$desc: GET $path -> la respuesta no contiene '$want_body'"
  else
    pass "$desc: GET $path -> HTTP $code"
  fi
  rm -f "$body"
}

echo "==> Esperando a que la app responda en ${BASE_URL}/health (máx. ${STARTUP_TIMEOUT}s)"
for ((i = 1; i <= STARTUP_TIMEOUT; i++)); do
  curl -fsS "${BASE_URL}/health" >/dev/null 2>&1 && break
  if ((i == STARTUP_TIMEOUT)); then
    echo "FALLO  la app no respondió en ${STARTUP_TIMEOUT}s"
    exit 1
  fi
  sleep 1
done

echo "==> Comprobando la app"
check "Health"           /health      200 '"status":"ok"'
check "Página principal" /            200 '<html'
check "Configuración"    /api/config  200 '"nextYear"'
check "Estáticos"        /app.js      200
check "Ruta inexistente" /no-existe   404

if [[ -n "$CONTAINER" ]]; then
  echo "==> Esperando el HEALTHCHECK de Docker de '${CONTAINER}' (máx. ${HEALTH_TIMEOUT}s)"
  status="desconocido"
  for ((i = 1; i <= HEALTH_TIMEOUT; i++)); do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo desconocido)"
    [[ "$status" == "healthy" || "$status" == "unhealthy" ]] && break
    sleep 1
  done
  if [[ "$status" == "healthy" ]]; then
    pass "HEALTHCHECK de Docker: $status"
  else
    fail "HEALTHCHECK de Docker: $status (esperado healthy)"
  fi
fi

if ((FAILED)); then
  echo "==> Smoke test FALLIDO"
  exit 1
fi
echo "==> Smoke test correcto"
