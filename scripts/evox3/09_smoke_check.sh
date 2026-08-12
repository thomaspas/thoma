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
# Vite may still be cold-starting after 11/16 restart — wait briefly before fail.
if ! curl -fsS --max-time 2 "http://127.0.0.1:${EVOX3_WEB_PORT}/" >/dev/null 2>&1; then
  log "Web UI not ready yet — waiting up to 60s on :${EVOX3_WEB_PORT}"
  for _ in $(seq 1 60); do
    if curl -fsS --max-time 2 "http://127.0.0.1:${EVOX3_WEB_PORT}/" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi
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

printf '\n=== graph analytics ===\n'
GRAPH_MARKER="$EVOX3_JINHUA_DIR/.evox3-graph-analytics"
ANALYTICS_PY="$EVOX3_JINHUA_DIR/secondbrain/graph/analytics.py"
if [ -f "$GRAPH_MARKER" ] && [ -f "$ANALYTICS_PY" ] \
  && grep -q 'EVOX3_GRAPH_ANALYTICS' "$ANALYTICS_PY" 2>/dev/null; then
  ok "graph analytics patch present"
  PASS=$((PASS + 1))
else
  warn "graph analytics patch missing — run ./scripts/evox3/17_graph_analytics.sh"
  FAIL=$((FAIL + 1))
fi
if [ "$LOGIN_CODE" = "200" ] && [ -f /tmp/evox3-smoke-login.json ]; then
  ACCESS_TOKEN="$(python3 - <<'PY'
import json
try:
    print(json.load(open("/tmp/evox3-smoke-login.json")).get("access_token") or "")
except Exception:
    print("")
PY
)"
  if [ -n "$ACCESS_TOKEN" ]; then
    SUM_CODE="$(curl -sS -o /tmp/evox3-smoke-graph-summary.json -w '%{http_code}' --max-time 15 \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/graph/analytics/summary" || true)"
    if [ "$SUM_CODE" = "200" ]; then
      ok "graph analytics summary HTTP 200"
      PASS=$((PASS + 1))
    else
      warn "graph analytics summary HTTP ${SUM_CODE} — run ./scripts/evox3/17_graph_analytics.sh"
      if [ -f /tmp/evox3-smoke-graph-summary.json ]; then
        warn "summary body: $(tr '\n' ' ' </tmp/evox3-smoke-graph-summary.json | head -c 240)"
      fi
      FAIL=$((FAIL + 1))
    fi
  else
    warn "no access_token in login response — skip analytics summary HTTP check"
    FAIL=$((FAIL + 1))
  fi
else
  warn "skip analytics summary HTTP check (login failed)"
  FAIL=$((FAIL + 1))
fi

printf '\n=== MCP ANGELICA server ===\n'
MCP_MARKER="$EVOX3_JINHUA_DIR/.evox3-mcp-angelica"
MCP_SERVER="$EVOX3_JINHUA_DIR/scripts/angelica_mcp_server.py"
MCP_CLIENT="$EVOX3_JINHUA_DIR/scripts/angelica_api_client.py"
VENV_PY="$EVOX3_JINHUA_DIR/.venv/bin/python"
if [ -f "$MCP_MARKER" ] && [ -f "$MCP_SERVER" ] && [ -f "$MCP_CLIENT" ] \
  && grep -q 'EVOX3_MCP_ANGELICA' "$MCP_SERVER" 2>/dev/null; then
  ok "MCP ANGELICA server installed"
  PASS=$((PASS + 1))
else
  warn "MCP ANGELICA server missing — run ./scripts/evox3/18_mcp_angelica.sh"
  FAIL=$((FAIL + 1))
fi
if [ -x "$VENV_PY" ] && "$VENV_PY" -c 'from mcp.server.fastmcp import FastMCP' 2>/dev/null; then
  ok "Jinhua venv FastMCP import OK"
  PASS=$((PASS + 1))
else
  warn "Jinhua venv missing FastMCP — run ./scripts/evox3/18_mcp_angelica.sh"
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

printf '\n=== React Flow graph UI ===\n'
GRAPH_UI_MARKER="$EVOX3_JINHUA_DIR/apps/web/.evox3-graph-ui-reactflow"
GRAPH_UI_WS="$EVOX3_JINHUA_DIR/apps/web/src/features/graph/GraphFlowWorkspace.tsx"
GRAPH_UI_PKG="$EVOX3_JINHUA_DIR/apps/web/package.json"
GRAPH_UI_SIDEBAR="$EVOX3_JINHUA_DIR/apps/web/src/components/AppSidebar.tsx"
if [ -f "$GRAPH_UI_MARKER" ]; then
  if [ -f "$GRAPH_UI_WS" ] \
    && grep -q 'EVOX3_GRAPH_UI' "$GRAPH_UI_WS" 2>/dev/null \
    && grep -q 'GraphFlowWorkspace' "$EVOX3_JINHUA_DIR/apps/web/src/App.tsx" 2>/dev/null \
    && grep -q '@xyflow/react' "$GRAPH_UI_PKG" 2>/dev/null \
    && grep -q '"graph"' "$GRAPH_UI_SIDEBAR" 2>/dev/null; then
    ok "React Flow graph UI present (marker + workspace + @xyflow + Graph nav)"
    PASS=$((PASS + 1))
  else
    warn "Graph UI marker present but incomplete — re-run ./scripts/evox3/24_graph_ui_reactflow.sh"
    FAIL=$((FAIL + 1))
  fi
else
  log "React Flow graph UI not installed (optional) — run ./scripts/evox3/24_graph_ui_reactflow.sh"
fi

printf '\n=== browser extension (opt-in) ===\n'
EXT_DIR="$SCRIPT_DIR/../../extensions/angelica-capture"
EXT_BUILD="$EXT_DIR/build/chrome-mv3-prod"
EXT_MANIFEST="$EXT_BUILD/manifest.json"
EXT_MARKER="$EXT_DIR/.evox3-built"
if [ -f "$EXT_MARKER" ]; then
  if [ -f "$EXT_MANIFEST" ]; then
    ok "ANGELICA Capture extension build present"
    PASS=$((PASS + 1))
  else
    warn "Extension marker present but build missing — re-run ./scripts/evox3/19_browser_extension.sh"
    FAIL=$((FAIL + 1))
  fi
else
  log "ANGELICA Capture extension not installed (optional) — run ./scripts/evox3/19_browser_extension.sh"
fi

printf '\n=== result: %s pass / %s fail ===\n' "$PASS" "$FAIL"
printf '\nOperator checklist (remote SSH — no visit to EVO-X3 needed):\n'
printf '  1) Run: ./scripts/evox3/21_remote_verify.sh  (expect REMOTE VERIFY OK)\n'
printf '  2) Upload + Greek chat: ./scripts/evox3/13_remote_go_live.sh\n'
printf '  3) Reboot test (from SSH): sudo reboot; then ./scripts/evox3/09_smoke_check.sh\n'
printf '  4) Done — paste 21_remote_verify output to Cursor if debugging\n'
printf '\nRelaunch kiosk now:\n'
printf '  ./scripts/evox3/10_relaunch_kiosk.sh\n'

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
ok "09_smoke_check.sh complete"
