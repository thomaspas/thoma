#!/usr/bin/env bash
# Post-reboot / stack-down resume: Docker + user units + remote verify.
# Run on EVO-X3 (SSH from Gaming-7). ASCII only.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

log "=== 25_post_reboot_resume: docker infra ==="
bash "$SCRIPT_DIR/02_ensure_jinhua_clone_and_docker.sh"

start_or_install_unit() {
  local unit="$1"
  local install_script="$2"
  if systemctl --user cat "$unit" >/dev/null 2>&1; then
    log "Starting $unit"
    systemctl --user start "$unit" || warn "start failed: $unit"
  else
    warn "$unit missing — running $install_script"
    bash "$SCRIPT_DIR/$install_script"
  fi
}

log "=== 25_post_reboot_resume: user units ==="
start_or_install_unit "evox3-bge-m3.service" "05_start_bge_m3_server.sh"
start_or_install_unit "evox3-jinhua-api.service" "06_migrate_and_start_api.sh"
start_or_install_unit "evox3-jinhua-web.service" "07_start_frontend_and_kiosk.sh"

# Ensure docker unit is recorded as started (oneshot RemainAfterExit).
systemctl --user start evox3-jinhua-docker.service 2>/dev/null || true

log "Waiting for stack ports (5432, 8002, 8000, 5173)"
wait_for_tcp 127.0.0.1 5432 90 || die "Postgres :5432 still closed after 02"
wait_for_tcp 127.0.0.1 "${EVOX3_BGE_PORT}" 90 || warn "bge-m3 :${EVOX3_BGE_PORT} TCP not open"
wait_for_tcp 127.0.0.1 "${EVOX3_API_PORT}" 90 || warn "API :${EVOX3_API_PORT} TCP not open"
wait_for_tcp 127.0.0.1 "${EVOX3_WEB_PORT}" 90 || warn "Web :${EVOX3_WEB_PORT} TCP not open"

_http_ok() {
  local url="$1"
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || echo 000)"
  [ "$code" = "200" ] || [ "$code" = "307" ] || [ "$code" = "302" ]
}

if _http_ok "http://127.0.0.1:${EVOX3_BGE_PORT}/health"; then
  ok "bge-m3 health 200"
else
  warn "bge-m3 /health not 200 yet"
fi
if _http_ok "http://127.0.0.1:${EVOX3_API_PORT}/docs"; then
  ok "API /docs 200"
else
  warn "API /docs not 200 yet"
fi
if _http_ok "http://127.0.0.1:${EVOX3_WEB_PORT}/"; then
  ok "Web UI 200"
else
  warn "Web UI not 200 yet"
fi

printf '\n=== unit status ===\n'
for unit in evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service; do
  state="$(systemctl --user is-active "$unit" 2>/dev/null || echo missing)"
  printf '%s %s\n' "$state" "$unit"
done

# Brand / skip-auth are idempotent; keep kiosk usable after upstream resets.
if [ "${EVOX3_SKIP_BRAND_RESUME:-0}" != "1" ]; then
  log "=== skip-auth + brand (idempotent) ==="
  bash "$SCRIPT_DIR/11_skip_auth_ui.sh" || warn "11_skip_auth_ui.sh failed"
  bash "$SCRIPT_DIR/16_brand_angelica.sh" || warn "16_brand_angelica.sh failed"
fi

log "=== 21_remote_verify ==="
bash "$SCRIPT_DIR/21_remote_verify.sh"
ok "25_post_reboot_resume.sh finished — paste 21 output to Cursor if anything failed"
