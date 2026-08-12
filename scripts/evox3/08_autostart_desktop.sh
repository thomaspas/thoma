#!/usr/bin/env bash
# Enable user services + desktop autostart entry for kiosk on login.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd systemctl

AUTOSTART_DIR="$HOME/.config/autostart"
ensure_dir "$AUTOSTART_DIR"

for unit in evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service; do
  if [ -f "$HOME/.config/systemd/user/$unit" ]; then
    systemctl --user enable "$unit"
    ok "Enabled $unit"
  else
    warn "Unit missing: $unit (run earlier scripts first)"
  fi
done

enable_linger_hint

KIOSK_WRAPPER="$HOME/ai_apps/bin/evox3-jinhua-kiosk.sh"
ensure_dir "$(dirname "$KIOSK_WRAPPER")"

cat > "$KIOSK_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export DISPLAY="\${DISPLAY:-:0}"
export XAUTHORITY="\${XAUTHORITY:-\$HOME/.Xauthority}"
URL="http://127.0.0.1:${EVOX3_WEB_PORT}"

# Wait for frontend (services may still be starting after login).
for _ in \$(seq 1 120); do
  if curl -fsS "\$URL" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

BROWSER=""
for c in chromium-browser chromium google-chrome google-chrome-stable firefox; do
  if command -v "\$c" >/dev/null 2>&1; then
    BROWSER="\$c"
    break
  fi
done
[ -n "\$BROWSER" ] || exit 0

pkill -f "kiosk.*${EVOX3_WEB_PORT}" 2>/dev/null || true
if [ "\$BROWSER" = "firefox" ]; then
  exec "\$BROWSER" -kiosk "\$URL"
else
  exec "\$BROWSER" --kiosk --app="\$URL" --no-first-run --disable-session-crashed-bubble
fi
EOF
chmod +x "$KIOSK_WRAPPER"

DESKTOP_FILE="$AUTOSTART_DIR/evox3-jinhua-kiosk.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=EVO-X3 Jinhua Second Brain Kiosk
Comment=Fullscreen Second Brain UI on login
Exec=${KIOSK_WRAPPER}
X-GNOME-Autostart-enabled=true
Terminal=false
EOF

ok "Wrote $DESKTOP_FILE"
ok "Wrote $KIOSK_WRAPPER"
ok "08_autostart_desktop.sh complete — kiosk starts on desktop login"
