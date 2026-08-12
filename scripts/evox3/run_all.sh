#!/usr/bin/env bash
# Run LOCAL FULL setup steps 01..08 in order on EVO-X3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

log "EVO-X3 LOCAL FULL — running scripts 01..11"
for step in \
  01_stop_legacy_mvp.sh \
  02_ensure_jinhua_clone_and_docker.sh \
  03_write_local_env.sh \
  04_install_python_deps.sh \
  05_start_bge_m3_server.sh \
  06_migrate_and_start_api.sh \
  07_start_frontend_and_kiosk.sh \
  08_autostart_desktop.sh \
  11_skip_auth_ui.sh \
  09_smoke_check.sh \
  10_relaunch_kiosk.sh
do
  log "=== $step ==="
  bash "$SCRIPT_DIR/$step"
done

ok "LOCAL FULL pipeline finished"
printf '\nNext:\n'
printf '  1) Kiosk should open dashboard (no Register/Login) as %s\n' "$EVOX3_LOCAL_EMAIL"
printf '  2) Confirm llama-server on :11434 is running\n'
printf '  3) Ingest a small markdown note and ask in Greek\n'
printf '  4) Logout/login on the EVO-X3 desktop to verify kiosk autostart\n'
