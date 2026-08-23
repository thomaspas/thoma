#!/usr/bin/env bash
# Post-reboot OR fresh-stack resume: Docker + units (or full bootstrap) + verify.
# Run on EVO-X3 (SSH from Gaming-7). ASCII only.
#
# Runtime evidence 2026-08-23: after wipe/missing clone, systemctl start fails with
# "Unit not found" — must run 03..07 (or run_all), not only start. Docker image
# pulls are large; do NOT Ctrl+C during 02.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

HOST_NOW="$(hostname -s 2>/dev/null || hostname)"
if ! printf '%s' "$HOST_NOW" | grep -qi 'EVO-X3'; then
  die "Run 25 on EVO-X3 only (hostname=${HOST_NOW}). SSH: ssh ${EVOX3_SSH:-thomas-pashoulas@192.168.1.9}"
fi

unit_exists() {
  systemctl --user cat "$1" >/dev/null 2>&1
}

log "=== 25_post_reboot_resume: docker infra (may pull large images — do not Ctrl+C) ==="
bash "$SCRIPT_DIR/02_ensure_jinhua_clone_and_docker.sh"
enable_linger_hint

NEED_BOOTSTRAP=0
if ! unit_exists "evox3-bge-m3.service" \
  || ! unit_exists "evox3-jinhua-api.service" \
  || ! unit_exists "evox3-jinhua-web.service"; then
  NEED_BOOTSTRAP=1
fi
if [ ! -f "$EVOX3_JINHUA_DIR/.env" ]; then
  NEED_BOOTSTRAP=1
fi
if [ ! -x "$EVOX3_JINHUA_DIR/.venv/bin/python" ] && [ ! -d "$EVOX3_JINHUA_DIR/.venv" ]; then
  # venv path may vary; missing .env is the stronger signal — keep bootstrap if units missing
  :
fi

if [ "$NEED_BOOTSTRAP" = "1" ]; then
  warn "Fresh / incomplete stack detected (missing units or .env) — running 03..11+16 bootstrap"
  for step in \
    03_write_local_env.sh \
    04_install_python_deps.sh \
    05_start_bge_m3_server.sh \
    06_migrate_and_start_api.sh \
    07_start_frontend_and_kiosk.sh \
    08_autostart_desktop.sh \
    11_skip_auth_ui.sh \
    16_brand_angelica.sh
  do
    log "=== $step ==="
    bash "$SCRIPT_DIR/$step"
  done
else
  log "=== 25_post_reboot_resume: restart existing user units ==="
  for unit in evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service; do
    systemctl --user start "$unit" || warn "start failed: $unit"
  done
  if [ "${EVOX3_SKIP_BRAND_RESUME:-0}" != "1" ]; then
    log "=== skip-auth + brand (idempotent) ==="
    bash "$SCRIPT_DIR/11_skip_auth_ui.sh" || warn "11_skip_auth_ui.sh failed"
    bash "$SCRIPT_DIR/16_brand_angelica.sh" || warn "16_brand_angelica.sh failed"
  fi
fi

log "Waiting for stack ports (5432, 8002, 8000, 5173)"
wait_for_tcp 127.0.0.1 5432 120 || die "Postgres :5432 still closed — re-run 02 without Ctrl+C"
wait_for_tcp 127.0.0.1 "${EVOX3_BGE_PORT}" 180 || warn "bge-m3 :${EVOX3_BGE_PORT} TCP not open"
wait_for_tcp 127.0.0.1 "${EVOX3_API_PORT}" 120 || warn "API :${EVOX3_API_PORT} TCP not open"
wait_for_tcp 127.0.0.1 "${EVOX3_WEB_PORT}" 120 || warn "Web :${EVOX3_WEB_PORT} TCP not open"

_http_ok() {
  local url="$1"
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || echo 000)"
  [ "$code" = "200" ] || [ "$code" = "307" ] || [ "$code" = "302" ]
}

_http_ok "http://127.0.0.1:${EVOX3_BGE_PORT}/health" && ok "bge-m3 health 200" || warn "bge-m3 /health not 200 yet"
_http_ok "http://127.0.0.1:${EVOX3_API_PORT}/docs" && ok "API /docs 200" || warn "API /docs not 200 yet"
_http_ok "http://127.0.0.1:${EVOX3_WEB_PORT}/" && ok "Web UI 200" || warn "Web UI not 200 yet"

printf '\n=== unit status ===\n'
for unit in evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service; do
  state="$(systemctl --user is-active "$unit" 2>/dev/null || echo missing)"
  printf '%s %s\n' "$state" "$unit"
done

log "=== 10_relaunch_kiosk ==="
bash "$SCRIPT_DIR/10_relaunch_kiosk.sh" || warn "kiosk relaunch failed (DISPLAY/Wayland?)"

log "=== 21_remote_verify ==="
bash "$SCRIPT_DIR/21_remote_verify.sh"
ok "25_post_reboot_resume.sh finished — paste 21 output to Cursor if anything failed"
