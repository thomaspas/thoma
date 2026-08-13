#!/usr/bin/env bash
# Diagnose ERR_CONNECTION_REFUSED on :5173 and start Vite on EVO-X3 when needed.
# Run in the SAME Cursor window as Simple Browser.
# Usage:
#   ./scripts/evox3/27_web_ui_preview.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl

HOST="$(hostname -s 2>/dev/null || hostname)"
ON_EVOX3=0
if printf '%s' "$HOST" | grep -qi 'EVO-X3'; then
  ON_EVOX3=1
fi

WEB_URL="http://127.0.0.1:${EVOX3_WEB_PORT}/"

port_open() {
  python3 -c "
import socket, sys
s = socket.socket()
s.settimeout(1)
try:
    r = s.connect_ex(('127.0.0.1', int('${EVOX3_WEB_PORT}')))
finally:
    s.close()
sys.exit(0 if r == 0 else 1)
" 2>/dev/null
}

web_http_ok() {
  local code
  code="$(curl -fsS -o /dev/null -w '%{http_code}' --max-time 3 "$WEB_URL" 2>/dev/null || printf '000')"
  case "$code" in
    200|301|302|307|308) return 0 ;;
    *) return 1 ;;
  esac
}

wait_web() {
  local i
  for i in $(seq 1 60); do
    if web_http_ok; then
      return 0
    fi
    sleep 1
  done
  return 1
}

printf '\n=== WEB UI PREVIEW CHECK (:%s) ===\n' "$EVOX3_WEB_PORT"
printf 'hostname=%s on_evox3=%s\n' "$HOST" "$ON_EVOX3"
printf 'url=%s\n' "$WEB_URL"

if port_open; then
  ok "tcp 127.0.0.1:${EVOX3_WEB_PORT} open"
else
  warn "tcp 127.0.0.1:${EVOX3_WEB_PORT} CLOSED (ERR_CONNECTION_REFUSED if you browse it here)"
fi

if web_http_ok; then
  ok "HTTP OK $WEB_URL"
else
  warn "HTTP failed $WEB_URL"
fi

if [ "$ON_EVOX3" -eq 0 ]; then
  warn "This machine is NOT EVO-X3. Vite listens only on EVO 127.0.0.1:${EVOX3_WEB_PORT}."
  warn "Simple Browser here hits THIS localhost — Connection refused is expected."
  printf '\nFix (Gaming-7 Cursor Desktop):\n'
  printf '  1) Ctrl+Shift+P -> Remote-SSH: Connect to Host\n'
  printf '  2) thomas-pashoulas@192.168.1.8  (or Host evo-x3)\n'
  printf '  3) Open /home/thomas-pashoulas/thoma\n'
  printf '  4) Title bar must show SSH: evo-x3 / EVO-X3\n'
  printf '  5) Ports panel -> Forward %s -> Simple Browser http://127.0.0.1:%s\n' "$EVOX3_WEB_PORT" "$EVOX3_WEB_PORT"
  printf '  6) In THAT window: ./scripts/evox3/27_web_ui_preview.sh\n'
  printf '\nDo NOT bind Vite to 0.0.0.0. Do NOT open :%s (API docs).\n' "$EVOX3_API_PORT"
  printf 'Guide: docs/CURSOR_REMOTE_SSH.md\n'
  exit 2
fi

if web_http_ok; then
  ok "ANGELICA UI is up on EVO. Forward port ${EVOX3_WEB_PORT} in Cursor Ports, then Simple Browser."
  printf 'Never use kiosk URL :%s\n' "$EVOX3_API_PORT"
  ok "27_web_ui_preview.sh complete"
  exit 0
fi

log "On EVO-X3 but UI down — starting evox3-jinhua-web.service"
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user enable --now evox3-jinhua-web.service 2>/dev/null || true
  systemctl --user restart evox3-jinhua-web.service 2>/dev/null || true
fi

if wait_web; then
  ok "Web UI came up after unit start"
  ok "27_web_ui_preview.sh complete"
  exit 0
fi

warn "Unit start did not open :${EVOX3_WEB_PORT} — running 07_start_frontend_and_kiosk.sh"
if [ -x "$SCRIPT_DIR/07_start_frontend_and_kiosk.sh" ]; then
  bash "$SCRIPT_DIR/07_start_frontend_and_kiosk.sh"
else
  die "Missing $SCRIPT_DIR/07_start_frontend_and_kiosk.sh"
fi

if wait_web; then
  ok "Web UI came up after 07"
  ok "27_web_ui_preview.sh complete"
  exit 0
fi

warn "Still down. Logs:"
journalctl --user -u evox3-jinhua-web.service -n 80 --no-pager 2>/dev/null || true
die "Frontend not ready on :${EVOX3_WEB_PORT} — see journalctl --user -u evox3-jinhua-web"
