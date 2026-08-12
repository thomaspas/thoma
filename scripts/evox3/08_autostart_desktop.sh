#!/usr/bin/env bash
# Enable user services + desktop autostart entry for kiosk on login.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd systemctl

AUTOSTART_DIR="$HOME/.config/autostart"
ensure_dir "$AUTOSTART_DIR"

# Docker compose first — API login needs Postgres after reboot.
if [ ! -f "$HOME/.config/systemd/user/evox3-jinhua-docker.service" ]; then
  if [ -d "$EVOX3_JINHUA_DIR" ] && command -v docker >/dev/null 2>&1; then
    install_jinhua_docker_unit
  else
    warn "Unit missing: evox3-jinhua-docker.service (run 02 first)"
  fi
fi

for unit in evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service; do
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

KIOSK_URL="http://127.0.0.1:${EVOX3_WEB_PORT}"
if [ "$EVOX3_WEB_PORT" = "$EVOX3_API_PORT" ]; then
  die "EVOX3_WEB_PORT cannot equal EVOX3_API_PORT (${EVOX3_API_PORT})"
fi

cat > "$KIOSK_WRAPPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
URL="${KIOSK_URL}"

# Attach to the LOCAL graphical session (works from SSH when desktop user is logged in).
UID_NUM="\$(id -u)"
export XDG_RUNTIME_DIR="\${XDG_RUNTIME_DIR:-/run/user/\${UID_NUM}}"
if [ -z "\${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "\${XDG_RUNTIME_DIR}/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=\${XDG_RUNTIME_DIR}/bus"
fi
if [ -z "\${WAYLAND_DISPLAY:-}" ]; then
  for wl in wayland-0 wayland-1; do
    if [ -S "\${XDG_RUNTIME_DIR}/\${wl}" ]; then
      export WAYLAND_DISPLAY="\$wl"
      break
    fi
  done
fi
export DISPLAY="\${DISPLAY:-:0}"
if [ -z "\${XAUTHORITY:-}" ] || [ ! -f "\${XAUTHORITY}" ]; then
  for candidate in \
    "\$HOME/.Xauthority" \
    "\${XDG_RUNTIME_DIR}/gdm/Xauthority" \
    "\${XDG_RUNTIME_DIR}"/.mutter-Xwaylandauth.*
  do
    if [ -f "\$candidate" ]; then
      export XAUTHORITY="\$candidate"
      break
    fi
  done
fi

echo "[*] EVO-X3 kiosk target: \$URL" >&2
echo "[*] DISPLAY=\${DISPLAY} WAYLAND_DISPLAY=\${WAYLAND_DISPLAY:-none} XAUTHORITY=\${XAUTHORITY:-none}" >&2

# Wait for frontend (services may still be starting after login).
for _ in \$(seq 1 120); do
  if curl -fsS "\$URL" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Prefer Flatpak Chromium when present (apt chromium is often blocked on EVO-X3).
BROWSER=""
FLATPAK_APP=""
if command -v flatpak >/dev/null 2>&1; then
  if flatpak info io.github.ungoogled_software.ungoogled_chromium >/dev/null 2>&1; then
    FLATPAK_APP="io.github.ungoogled_software.ungoogled_chromium"
  elif flatpak info org.chromium.Chromium >/dev/null 2>&1; then
    FLATPAK_APP="org.chromium.Chromium"
  fi
fi
if [ -z "\$FLATPAK_APP" ]; then
  for c in chromium-browser chromium google-chrome google-chrome-stable firefox; do
    if command -v "\$c" >/dev/null 2>&1; then
      BROWSER="\$c"
      break
    fi
  done
fi

if [ -z "\$BROWSER" ] && [ -z "\$FLATPAK_APP" ]; then
  echo "No browser found (install Flatpak Chromium; apt chromium is broken on this node)" >&2
  exit 1
fi

# Kill stale API-docs (:8000) and UI (:5173) browser instances before relaunch.
pkill -f 'io.github.ungoogled_software.ungoogled_chromium' 2>/dev/null || true
pkill -f 'org.chromium.Chromium' 2>/dev/null || true
pkill -f 'chromium.*127.0.0.1:${EVOX3_API_PORT}' 2>/dev/null || true
pkill -f 'chromium.*127.0.0.1:${EVOX3_WEB_PORT}' 2>/dev/null || true
pkill -f 'chrome.*127.0.0.1:${EVOX3_API_PORT}' 2>/dev/null || true
pkill -f 'chrome.*127.0.0.1:${EVOX3_WEB_PORT}' 2>/dev/null || true
sleep 1

OZONE_ARGS=()
if [ -n "\${WAYLAND_DISPLAY:-}" ]; then
  OZONE_ARGS+=(--ozone-platform=wayland)
fi

if [ -n "\$FLATPAK_APP" ]; then
  # Flatpak Chromium: URL as final arg; --app= alone is unreliable across runtimes.
  exec flatpak run "\$FLATPAK_APP" --kiosk --no-first-run --disable-session-crashed-bubble "\${OZONE_ARGS[@]}" "\$URL"
elif [ "\$BROWSER" = "firefox" ]; then
  exec "\$BROWSER" -kiosk "\$URL"
else
  exec "\$BROWSER" --kiosk --app="\$URL" --no-first-run --disable-session-crashed-bubble "\${OZONE_ARGS[@]}"
fi
EOF
chmod +x "$KIOSK_WRAPPER"

DESKTOP_FILE="$AUTOSTART_DIR/evox3-jinhua-kiosk.desktop"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=${EVOX3_BRAND_NAME} Kiosk
Comment=Fullscreen ${EVOX3_BRAND_NAME} UI on login
Exec=${KIOSK_WRAPPER}
X-GNOME-Autostart-enabled=true
Terminal=false
EOF

ok "Wrote $DESKTOP_FILE"
ok "Wrote $KIOSK_WRAPPER"
ok "08_autostart_desktop.sh complete — ${EVOX3_BRAND_NAME} kiosk starts on desktop login"
