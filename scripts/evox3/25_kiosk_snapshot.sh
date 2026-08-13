#!/usr/bin/env bash
# Capture the EVO-X3 GNOME/kiosk display to a PNG (SSH / Cursor Remote SSH).
# GNOME-first (gnome-screenshot / Shell Screenshot). grim is wlroots fallback only.
# Usage (on EVO-X3):
#   ./scripts/evox3/25_kiosk_snapshot.sh
#   EVOX3_KIOSK_SNAPSHOT=/tmp/foo.png ./scripts/evox3/25_kiosk_snapshot.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

OUT="${EVOX3_KIOSK_SNAPSHOT:-/tmp/angelica-kiosk.png}"
ensure_dir "$(dirname "$OUT")"

setup_local_graphical_env

shot_gdbus() {
  command -v gdbus >/dev/null 2>&1 || return 1
  [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 1
  local reply
  reply="$(gdbus call --session \
    --dest org.gnome.Shell.Screenshot \
    --object-path /org/gnome/Shell/Screenshot \
    --method org.gnome.Shell.Screenshot.Screenshot \
    false false "$OUT" 2>/dev/null || true)"
  printf '%s' "$reply" | grep -q 'true'
}

shot_gnome_screenshot() {
  command -v gnome-screenshot >/dev/null 2>&1 || return 1
  gnome-screenshot -f "$OUT" >/dev/null 2>&1
}

shot_grim() {
  command -v grim >/dev/null 2>&1 || return 1
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    grim "$OUT" >/dev/null 2>&1
  else
    return 1
  fi
}

METHOD=""
if shot_gdbus && [ -s "$OUT" ]; then
  METHOD="org.gnome.Shell.Screenshot"
elif shot_gnome_screenshot && [ -s "$OUT" ]; then
  METHOD="gnome-screenshot"
elif shot_grim && [ -s "$OUT" ]; then
  METHOD="grim"
else
  warn "Could not capture display. Need a logged-in GNOME session on EVO-X3."
  warn "Check: ./scripts/evox3/22_operator_context_check.sh"
  warn "Graphical: ls /run/user/$(id -u)/wayland-* ; echo DBUS=\${DBUS_SESSION_BUS_ADDRESS:-none}"
  die "Install gnome-screenshot (GNOME) or grim (fallback). Re-run after desktop login."
fi

BYTES="$(wc -c <"$OUT" | tr -d ' ')"
ok "Kiosk snapshot: $OUT ($BYTES bytes, method=$METHOD)"
printf 'Open in Cursor Remote SSH: %s\n' "$OUT"
printf 'Live UI (same app, not monitor pixels): http://127.0.0.1:%s\n' "$EVOX3_WEB_PORT"
printf 'Live monitor: ./scripts/evox3/26_gnome_remote_desktop.sh then Remmina RDP :3389\n'
ok "25_kiosk_snapshot.sh complete"
