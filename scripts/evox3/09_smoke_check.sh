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

check_http "LLM     " "${EVOX3_LLM_BASE_URL}/models"
check_http "bge-m3  " "http://127.0.0.1:${EVOX3_BGE_PORT}/health"
check_http "API docs" "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/docs"
check_http "Web UI  " "http://127.0.0.1:${EVOX3_WEB_PORT}/"

if command -v systemctl >/dev/null 2>&1; then
  printf '\n=== systemd user units ===\n'
  for unit in evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service; do
    if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
      ok "$unit active"
      PASS=$((PASS + 1))
    else
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

printf '\n=== result: %s pass / %s fail ===\n' "$PASS" "$FAIL"
printf '\nNext on EVO-X3 desktop:\n'
printf '  1) Kiosk must open http://127.0.0.1:%s (NOT :8000 API docs)\n' "$EVOX3_WEB_PORT"
printf '  2) No Register/Login — auto-session via 11_skip_auth_ui.sh\n'
printf '  3) Upload a small .md note\n'
printf '  4) Ask a Greek question in chat\n'
printf '  5) Reboot once to confirm autostart (services + kiosk)\n'
printf '\nRelaunch kiosk now (kills stale :8000 browsers):\n'
printf '  ./scripts/evox3/10_relaunch_kiosk.sh\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
ok "09_smoke_check.sh complete"
