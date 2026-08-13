#!/usr/bin/env bash
# Stop/disable the Jinhua kiosk stack. Keep llama-server, Open WebUI, SearXNG.
# Does not rm -rf the clone or ~/models. Archives the clone once (rename).
# Idempotent. Run on EVO-X3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd systemctl

log "Retiring Jinhua kiosk stack (disable, not wipe)"
log "Will NOT stop llama-server, Open WebUI, or SearXNG"
log "Will NOT delete ~/models or Docker volumes"

# 1) Stop/disable Jinhua user units while the clone still exists (ExecStop compose).
for unit in $EVOX3_JINHUA_UNITS; do
  stop_disable_user_unit "$unit"
done
reload_user_systemd || true

# 2) Disable desktop autostart / gtk-launch entries (do not delete wrappers).
disable_desktop_entry() {
  local path="$1"
  if [ ! -f "$path" ]; then
    ok "No desktop entry: $path"
    return 0
  fi
  if grep -q '^Hidden=true$' "$path" 2>/dev/null && grep -q '^X-GNOME-Autostart-enabled=false$' "$path" 2>/dev/null; then
    ok "Already disabled: $path"
    return 0
  fi
  if grep -q '^Hidden=' "$path"; then
    sed -i 's/^Hidden=.*/Hidden=true/' "$path"
  else
    printf '\nHidden=true\n' >>"$path"
  fi
  if grep -q '^X-GNOME-Autostart-enabled=' "$path"; then
    sed -i 's/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/' "$path"
  else
    printf 'X-GNOME-Autostart-enabled=false\n' >>"$path"
  fi
  ok "Disabled autostart: $path"
}

disable_desktop_entry "$HOME/.config/autostart/evox3-jinhua-kiosk.desktop"
disable_desktop_entry "$HOME/.local/share/applications/evox3-jinhua-kiosk.desktop"

# 3) Stop the dedicated kiosk wrapper / kiosk Chromium profile only.
if pgrep -af 'evox3-jinhua-kiosk' >/dev/null 2>&1; then
  pkill -f 'evox3-jinhua-kiosk' 2>/dev/null || true
  ok "Stopped evox3-jinhua-kiosk processes"
else
  ok "No evox3-jinhua-kiosk process"
fi

# 4) Archive clone (rename). Keep .env / uploads for rollback. Never rm -rf.
archive_jinhua_clone() {
  local live="$EVOX3_JINHUA_DIR"
  local dest="$EVOX3_JINHUA_ARCHIVE"
  if [ ! -d "$live" ]; then
    if [ -d "$dest" ]; then
      ok "Jinhua clone already archived at $dest"
    else
      ok "No Jinhua clone at $live (nothing to archive)"
    fi
    return 0
  fi
  if [ -d "$dest" ]; then
    dest="${EVOX3_JINHUA_ARCHIVE}-$(date +%Y%m%d)"
    if [ -d "$dest" ]; then
      dest="${EVOX3_JINHUA_ARCHIVE}-$(date +%Y%m%d-%H%M%S)"
    fi
    warn "Archive path exists; using $dest"
  fi
  ensure_dir "$(dirname "$dest")"
  mv "$live" "$dest"
  ok "Archived $live -> $dest"
}

archive_jinhua_clone

printf '\n=== KEPT (not touched) ===\n'
printf '  llama-server :11434\n'
printf '  ~/models/\n'
printf '  Open WebUI :8080\n'
printf '  SearXNG :8888\n'
printf '  Docker volumes (no wipe)\n'

ok "26_retire_jinhua_kiosk.sh complete"
printf '  Next: ./scripts/evox3/27_gbrain_angelica.sh\n'
printf '  Rollback: restore archived clone, then systemctl --user enable --now the evox3-jinhua-* units\n'
