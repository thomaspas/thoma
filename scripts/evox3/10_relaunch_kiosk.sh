#!/usr/bin/env bash
# Kill stale kiosk browsers (esp. :8000 API docs) and relaunch Flatpak/Chromium on :5173.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl

URL="http://127.0.0.1:${EVOX3_WEB_PORT}"

# Always rewrite the wrapper first so autostart cannot resurrect :8000.
bash "$SCRIPT_DIR/08_autostart_desktop.sh"

log "Checking frontend $URL"
READY=0
for _ in $(seq 1 60); do
  if curl -fsS "$URL" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
[ "$READY" -eq 1 ] || die "Frontend not ready on :${EVOX3_WEB_PORT} — start evox3-jinhua-web.service first"

setup_local_graphical_env

# Kill ANY leftover Second Brain / API-docs browser tabs (previous sessions used :8000).
log "Stopping stale Chromium/Firefox kiosk processes"
if command -v flatpak >/dev/null 2>&1; then
  flatpak kill io.github.ungoogled_software.ungoogled_chromium 2>/dev/null || true
  flatpak kill org.chromium.Chromium 2>/dev/null || true
fi
pkill -f 'io.github.ungoogled_software.ungoogled_chromium' 2>/dev/null || true
pkill -f 'org.chromium.Chromium' 2>/dev/null || true
pkill -f 'chromium.*127.0.0.1:8000' 2>/dev/null || true
pkill -f 'chromium.*127.0.0.1:5173' 2>/dev/null || true
pkill -f 'chrome.*127.0.0.1:8000' 2>/dev/null || true
pkill -f 'chrome.*127.0.0.1:5173' 2>/dev/null || true
pkill -f 'evox3-jinhua-kiosk' 2>/dev/null || true
sleep 2

KIOSK_WRAPPER="$HOME/ai_apps/bin/evox3-jinhua-kiosk.sh"
[ -x "$KIOSK_WRAPPER" ] || die "Missing $KIOSK_WRAPPER"

# Prove wrapper points at Vite, not API docs.
if grep -q ":${EVOX3_API_PORT}" "$KIOSK_WRAPPER" && ! grep -q ":${EVOX3_WEB_PORT}" "$KIOSK_WRAPPER"; then
  die "Kiosk wrapper still targets API port :${EVOX3_API_PORT} — refuse to launch"
fi
if ! grep -q ":${EVOX3_WEB_PORT}" "$KIOSK_WRAPPER"; then
  die "Kiosk wrapper missing :${EVOX3_WEB_PORT}"
fi
if ! grep -q 'user-data-dir' "$KIOSK_WRAPPER"; then
  warn "Kiosk wrapper missing --user-data-dir — re-run 08_autostart_desktop.sh"
fi

log "Launching kiosk wrapper -> $URL"
: > /tmp/evox3-jinhua-kiosk.log
# Do NOT use bash -lc here — login shells drop DISPLAY/WAYLAND from SSH sessions.
ENV_ARGS=(
  LANG=en_US.UTF-8
  LC_ALL=en_US.UTF-8
  DISPLAY="${DISPLAY:-:0}"
  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}"
)
[ -n "${WAYLAND_DISPLAY:-}" ] && ENV_ARGS+=(WAYLAND_DISPLAY="$WAYLAND_DISPLAY")
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && ENV_ARGS+=(DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS")
[ -n "${XAUTHORITY:-}" ] && ENV_ARGS+=(XAUTHORITY="$XAUTHORITY")
nohup env "${ENV_ARGS[@]}" "$KIOSK_WRAPPER" >/tmp/evox3-jinhua-kiosk.log 2>&1 &
sleep 5

if ! kiosk_references_web_port && command -v systemd-run >/dev/null 2>&1; then
  log "First launch missed :${EVOX3_WEB_PORT} — retry via systemd-run --user in graphical session"
  systemd-run --user --collect --setenv=DISPLAY="${DISPLAY:-:0}" \
    --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
    --setenv=DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    --setenv=XAUTHORITY="${XAUTHORITY:-}" \
    -- "$KIOSK_WRAPPER" >>/tmp/evox3-jinhua-kiosk.log 2>&1 || true
  sleep 5
fi

APPS_DESKTOP="$HOME/.local/share/applications/evox3-jinhua-kiosk.desktop"
if ! kiosk_references_web_port && command -v gtk-launch >/dev/null 2>&1; then
  if [ -f "$APPS_DESKTOP" ] || [ -f "$HOME/.config/autostart/evox3-jinhua-kiosk.desktop" ]; then
    log "Retry via gtk-launch evox3-jinhua-kiosk (applications/ + autostart desktop entry)"
    env "${ENV_ARGS[@]}" gtk-launch evox3-jinhua-kiosk >>/tmp/evox3-jinhua-kiosk.log 2>&1 &
    sleep 5
  fi
fi

# Last resort: direct flatpak with dedicated profile + explicit URL (visible in /proc).
if ! kiosk_references_web_port; then
  LAUNCH_CMD="$(kiosk_launch_cmd "$URL" || true)"
  if [ -n "${LAUNCH_CMD:-}" ]; then
    log "Retry direct browser launch with dedicated profile -> $URL"
    # shellcheck disable=SC2086
    nohup env "${ENV_ARGS[@]}" bash -c "$LAUNCH_CMD" >>/tmp/evox3-jinhua-kiosk.log 2>&1 &
    sleep 5
  fi
fi

ok "Relaunched. Expect dashboard/chat at $URL (no Register/Login; NOT :${EVOX3_API_PORT})"
printf 'Log tail:\n'
tail -n 40 /tmp/evox3-jinhua-kiosk.log 2>/dev/null || true
printf '\nProcesses:\n'
kiosk_proc_snapshot | head -n 15 || true
if kiosk_references_web_port; then
  ok "Kiosk browser references :${EVOX3_WEB_PORT}"
elif ! pgrep -af 'ungoogled_chromium|org.chromium|chromium|firefox' >/dev/null 2>&1; then
  warn "No browser process — retry from SSH: ./scripts/evox3/10_relaunch_kiosk.sh"
  warn "Then: ./scripts/evox3/21_remote_verify.sh"
  warn "Diagnostic: ls -l \"\$XDG_RUNTIME_DIR\"/wayland-* \"\$XDG_RUNTIME_DIR\"/gdm/Xauthority 2>/dev/null; echo DISPLAY=\$DISPLAY"
else
  warn "Browser running but :${EVOX3_WEB_PORT} not yet in cmdline — wait_for_kiosk in 21 will poll"
fi
printf '\nIf you still see :%s in process args, paste this block back.\n' "$EVOX3_API_PORT"
printf 'Remote confirm: ./scripts/evox3/21_remote_verify.sh (no screen visit needed)\n'
printf 'Greek chat: ./scripts/evox3/13_remote_go_live.sh\n'
ok "10_relaunch_kiosk.sh complete"
