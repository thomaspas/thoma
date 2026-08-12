#!/usr/bin/env bash
# Install/start Jinhua Vite frontend and open Chromium kiosk on the local display.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd systemctl

WEB_DIR="$EVOX3_JINHUA_DIR/apps/web"
[ -d "$WEB_DIR" ] || die "Missing $WEB_DIR — is the Jinhua clone complete?"

if ! command -v npm >/dev/null 2>&1; then
  die "npm not found. Install Node.js 20+ (e.g. sudo apt install npm) then re-run."
fi

cd "$WEB_DIR"
log "npm install"
npm install

NPM_BIN="$(command -v npm)"
# Resolve to real path when possible (nvm/fnm shims can break systemd 203/EXEC).
if command -v readlink >/dev/null 2>&1; then
  NPM_BIN="$(readlink -f "$NPM_BIN" 2>/dev/null || printf '%s' "$NPM_BIN")"
fi
log "npm binary for systemd: $NPM_BIN"

UNIT_DIR="$(user_systemd_dir)"
UNIT_PATH="$UNIT_DIR/evox3-jinhua-web.service"

# Use bash -lc so nvm/fnm PATH works; avoid bare ExecStart=/usr/bin/npm (203/EXEC).
cat > "$UNIT_PATH" <<EOF
[Unit]
Description=EVO-X3 Jinhua SecondBrain Vite frontend (:${EVOX3_WEB_PORT})
After=network-online.target evox3-jinhua-api.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${WEB_DIR}
Environment=PATH=${PATH}
ExecStart=/bin/bash -lc 'cd "${WEB_DIR}" && exec "${NPM_BIN}" run dev -- --host 127.0.0.1 --port ${EVOX3_WEB_PORT}'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

reload_user_systemd
systemctl --user enable --now evox3-jinhua-web.service

log "Waiting for frontend http://127.0.0.1:${EVOX3_WEB_PORT}"
READY=0
for _ in $(seq 1 90); do
  if curl -fsS "http://127.0.0.1:${EVOX3_WEB_PORT}" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
[ "$READY" -eq 1 ] || die "Frontend did not become ready on :${EVOX3_WEB_PORT}"

URL="http://127.0.0.1:${EVOX3_WEB_PORT}"
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

LAUNCH_CMD="$(kiosk_launch_cmd "$URL" || true)"
if [ -z "${LAUNCH_CMD:-}" ]; then
  warn "No Chromium/Firefox/Flatpak browser found — open $URL manually"
  ok "07_start_frontend_and_kiosk.sh complete (kiosk skipped)"
  exit 0
fi

log "Launching kiosk: $LAUNCH_CMD"
pkill -f "kiosk.*${EVOX3_WEB_PORT}" 2>/dev/null || true
nohup bash -lc "$LAUNCH_CMD" >/tmp/evox3-jinhua-kiosk.log 2>&1 &

sleep 1
ok "Kiosk launched (log: /tmp/evox3-jinhua-kiosk.log)"
ok "07_start_frontend_and_kiosk.sh complete — $URL"
