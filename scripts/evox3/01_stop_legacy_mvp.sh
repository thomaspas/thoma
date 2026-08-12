#!/usr/bin/env bash
# Stop/disable the legacy Kuzu MVP second-brain.service (frees :8000).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

log "Stopping legacy MVP second-brain.service (if present)"

if systemctl --user list-unit-files 2>/dev/null | grep -q '^second-brain.service'; then
  systemctl --user stop second-brain.service 2>/dev/null || true
  systemctl --user disable second-brain.service 2>/dev/null || true
  ok "second-brain.service stopped and disabled"
else
  ok "second-brain.service not installed (nothing to stop)"
fi

# Also stop common legacy unit names from Arena/Kuzu experiments.
for unit in ye-kuzu-brain.service kuzu-arms-brain.service; do
  if systemctl --user list-unit-files 2>/dev/null | grep -q "^${unit}"; then
    systemctl --user stop "$unit" 2>/dev/null || true
    warn "Left $unit disabled? Not touching enable state (legacy system unit may be system-wide)"
  fi
  if systemctl list-unit-files 2>/dev/null | grep -q "^${unit}"; then
    warn "System unit $unit exists. Not stopping automatically (may require sudo). Free :8000 manually if needed."
  fi
done

if ss -tulpn 2>/dev/null | grep -q ':8000 '; then
  warn "Something is still listening on :8000:"
  ss -tulpn 2>/dev/null | grep ':8000 ' || true
  warn "Stop that process before starting Jinhua API on :8000, or set EVOX3_API_PORT to another port."
else
  ok "Port :8000 is free"
fi

ok "01_stop_legacy_mvp.sh complete"
