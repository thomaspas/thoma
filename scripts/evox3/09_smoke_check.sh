#!/usr/bin/env bash
# Smoke-check LOCAL FULL ports/services and print next operator steps.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl

PASS=0
FAIL=0

check_http() {
  local name="$1"
  local url="$2"
  local code
  code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || printf '000')"
  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "307" ] || [ "$code" = "308" ]; then
    ok "$name  HTTP $code  $url"
    PASS=$((PASS + 1))
  else
    warn "$name  HTTP $code  $url"
    FAIL=$((FAIL + 1))
  fi
}

printf '\n=== EVO-X3 LOCAL FULL smoke ===\n'

check_tcp() {
  local name="$1"
  local host="$2"
  local port="$3"
  if wait_for_tcp "$host" "$port" 2; then
    ok "$name  tcp ${host}:${port} open"
    PASS=$((PASS + 1))
  else
    warn "$name  tcp ${host}:${port} CLOSED — run ./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh"
    FAIL=$((FAIL + 1))
  fi
}

printf '\n=== docker infra (required after reboot) ===\n'
check_tcp "Postgres" "127.0.0.1" "5432"
check_tcp "Neo4j  " "127.0.0.1" "7687"

check_http "LLM     " "${EVOX3_LLM_BASE_URL}/models"
check_http "bge-m3  " "http://127.0.0.1:${EVOX3_BGE_PORT}/health"
check_http "API docs" "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/docs"
check_http "Web UI  " "http://127.0.0.1:${EVOX3_WEB_PORT}/"

if command -v systemctl >/dev/null 2>&1; then
  printf '\n=== systemd user units ===\n'
  for unit in evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service; do
    if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
      ok "$unit active"
      PASS=$((PASS + 1))
    else
      # oneshot RemainAfterExit units report "active" when successful; inactive = not started
      warn "$unit NOT active"
      FAIL=$((FAIL + 1))
    fi
  done
fi

if [ -f "$EVOX3_JINHUA_DIR/.env" ]; then
  printf '\n=== .env LLM alignment ===\n'
  ENV_MODEL="$(
    python3 - <<PY
from pathlib import Path
p = Path("$EVOX3_JINHUA_DIR/.env")
for line in p.read_text().splitlines():
    if line.startswith("LLM_MODEL="):
        print(line.split("=", 1)[1].strip())
        break
PY
  )"
  LIVE_MODEL="$(curl -fsS --max-time 5 "${EVOX3_LLM_BASE_URL}/models" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); m=d.get("data") or []
    print((m[0].get("id") if m else "") or "")
except Exception:
    print("")
' || true)"
  printf '  .env LLM_MODEL=%s\n' "${ENV_MODEL:-<missing>}"
  printf '  live /v1/models id=%s\n' "${LIVE_MODEL:-<unreachable>}"
  if [ -n "${LIVE_MODEL:-}" ] && [ "$ENV_MODEL" = "$LIVE_MODEL" ]; then
    ok "LLM_MODEL matches llama-server"
    PASS=$((PASS + 1))
  elif [ -n "${LIVE_MODEL:-}" ]; then
    warn "LLM_MODEL mismatch — re-run 03_write_local_env.sh then restart API"
    FAIL=$((FAIL + 1))
  else
    warn "Could not read live model id"
    FAIL=$((FAIL + 1))
  fi
fi

printf '\n=== skip-auth / local account ===\n'
APP_TSX="$EVOX3_JINHUA_DIR/apps/web/src/App.tsx"
AUTO_TS="$EVOX3_JINHUA_DIR/apps/web/src/evox3AutoAuth.ts"
MARKER="$EVOX3_JINHUA_DIR/apps/web/.evox3-skip-auth"
if [ -f "$MARKER" ] && [ -f "$AUTO_TS" ] && grep -q 'EVOX3_SKIP_AUTH' "$APP_TSX" 2>/dev/null; then
  ok "skip-auth patch present (App.tsx + evox3AutoAuth.ts)"
  PASS=$((PASS + 1))
else
  warn "skip-auth patch missing — run ./scripts/evox3/11_skip_auth_ui.sh"
  FAIL=$((FAIL + 1))
fi

LOGIN_BODY="$(python3 - <<PY
import json
print(json.dumps({"email": """${EVOX3_LOCAL_EMAIL}""", "password": """${EVOX3_LOCAL_PASSWORD}"""}))
PY
)"
LOGIN_CODE="$(curl -sS -o /tmp/evox3-smoke-login.json -w '%{http_code}' --max-time 10 \
  -X POST "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/auth/login" \
  -H 'Content-Type: application/json' \
  -d "$LOGIN_BODY" || true)"
if [ "$LOGIN_CODE" = "200" ]; then
  ok "local account login OK (${EVOX3_LOCAL_EMAIL})"
  PASS=$((PASS + 1))
else
  warn "local account login HTTP ${LOGIN_CODE}"
  if [ -f /tmp/evox3-smoke-login.json ]; then
    warn "login body: $(tr '\n' ' ' </tmp/evox3-smoke-login.json | head -c 240)"
  fi
  if ! wait_for_tcp 127.0.0.1 5432 1; then
    warn "Postgres :5432 is down — fix: ./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh"
  else
    warn "Postgres is up — try: ./scripts/evox3/11_skip_auth_ui.sh"
  fi
  FAIL=$((FAIL + 1))
fi

printf '\n=== %s brand ===\n' "$EVOX3_BRAND_NAME"
BRAND_MARKER="$EVOX3_JINHUA_DIR/apps/web/.evox3-brand-angelica"
SIDEBAR_TSX="$EVOX3_JINHUA_DIR/apps/web/src/components/AppSidebar.tsx"
INDEX_HTML="$EVOX3_JINHUA_DIR/apps/web/index.html"
if [ -f "$BRAND_MARKER" ] \
  && grep -q "$EVOX3_BRAND_NAME" "$SIDEBAR_TSX" 2>/dev/null \
  && grep -q "$EVOX3_BRAND_NAME" "$INDEX_HTML" 2>/dev/null; then
  ok "${EVOX3_BRAND_NAME} brand present (marker + sidebar + title)"
  PASS=$((PASS + 1))
else
  warn "${EVOX3_BRAND_NAME} brand missing — run ./scripts/evox3/16_brand_angelica.sh"
  FAIL=$((FAIL + 1))
fi

printf '\n=== result: %s pass / %s fail ===\n' "$PASS" "$FAIL"
printf '\nOperator checklist (human / on EVO-X3 desktop):\n'
printf '  1) Kiosk http://127.0.0.1:%s shows %s dashboard (NOT Register/Login, NOT :8000)\n' \
  "$EVOX3_WEB_PORT" "$EVOX3_BRAND_NAME"
printf '  2) Upload a small .md note\n'
printf '  3) Ask a Greek question in chat\n'
printf '  4) Reboot once; confirm systemd units + kiosk autostart\n'
printf '  5) Done — LOCAL FULL operator checklist complete\n'
printf '\nRelaunch kiosk now:\n'
printf '  ./scripts/evox3/10_relaunch_kiosk.sh\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
ok "09_smoke_check.sh complete"
