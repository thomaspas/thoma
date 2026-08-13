#!/usr/bin/env bash
# COMPLETE wipe of the Jinhua / IncubativeSecondBrain / ANGELICA kiosk stack on EVO-X3.
# Destroys Docker volumes (Postgres, Neo4j graph, MinIO). No rollback.
# Does NOT touch llama-server, ~/models, Open WebUI, SearXNG, or ~/thoma.
#
#   EVOX3_WIPE_JINHUA=YES ./scripts/evox3/29_wipe_jinhua.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd systemctl

if [ "${EVOX3_WIPE_JINHUA:-}" != "YES" ]; then
  die "Refusing wipe. This deletes Neo4j/Postgres volumes and the Jinhua clone. Re-run: EVOX3_WIPE_JINHUA=YES $0"
fi

log "FULL WIPE Jinhua — llama / ~/models / WebUI / SearXNG / thoma will NOT be touched"

# --- stop kiosk ---
pkill -f 'evox3-jinhua-kiosk' 2>/dev/null || true
pkill -f 'chromium.*127.0.0.1:5173' 2>/dev/null || true
pkill -f 'chrome.*127.0.0.1:5173' 2>/dev/null || true
rm -rf /tmp/evox3-jinhua-kiosk-chromium
rm -f /tmp/evox3-jinhua-kiosk.log
ok "Stopped kiosk wrapper / temp Chromium profile"

# --- stop units while clone still exists (compose ExecStop) ---
for unit in $EVOX3_JINHUA_UNITS; do
  stop_disable_user_unit "$unit"
done

compose_down() {
  local dir="$1"
  local compose=""
  [ -d "$dir" ] || return 0
  if [ -f "$dir/docker-compose.yml" ]; then
    compose="$dir/docker-compose.yml"
  elif [ -f "$dir/compose.yml" ]; then
    compose="$dir/compose.yml"
  else
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    log "docker compose down -v in $dir"
    (cd "$dir" && docker compose down -v) || warn "compose down failed in $dir"
  else
    warn "docker not on PATH — skip compose down in $dir"
  fi
}

compose_down "$EVOX3_JINHUA_DIR"
shopt -s nullglob
for d in "$EVOX3_JINHUA_ARCHIVE" "$EVOX3_JINHUA_ARCHIVE"-*; do
  compose_down "$d"
done
shopt -u nullglob

# --- remove unit files ---
UNIT_DIR="$(user_systemd_dir)"
for unit in $EVOX3_JINHUA_UNITS; do
  if [ -f "$UNIT_DIR/$unit" ]; then
    rm -f "$UNIT_DIR/$unit"
    ok "Removed $UNIT_DIR/$unit"
  fi
done
reload_user_systemd || true

# --- desktop entries + wrapper ---
rm -f "$HOME/.config/autostart/evox3-jinhua-kiosk.desktop"
rm -f "$HOME/.local/share/applications/evox3-jinhua-kiosk.desktop"
rm -f "$HOME/ai_apps/bin/evox3-jinhua-kiosk.sh"
ok "Removed autostart / applications / kiosk wrapper"

# --- directories ---
rm_tree() {
  local p="$1"
  if [ -e "$p" ]; then
    rm -rf "$p"
    ok "Removed $p"
  else
    ok "Already gone: $p"
  fi
}

rm_tree "$EVOX3_JINHUA_DIR"
shopt -s nullglob
for d in "$EVOX3_JINHUA_ARCHIVE" "$EVOX3_JINHUA_ARCHIVE"-*; do
  rm_tree "$d"
done
shopt -u nullglob
rm_tree "$EVOX3_BGE_DIR"

if [ "${EVOX3_WIPE_HF_CACHE:-0}" = "1" ]; then
  rm_tree "$HOME/.cache/huggingface"
else
  log "Left ~/.cache/huggingface (bge-m3 weights). Wipe with EVOX3_WIPE_HF_CACHE=1 if desired."
fi

if [ "${EVOX3_WIPE_DOCKER_IMAGES:-0}" = "1" ] && command -v docker >/dev/null 2>&1; then
  log "Removing dangling docker images (optional flag)"
  docker image prune -f || true
else
  log "Left docker images (postgres/neo4j/minio). Set EVOX3_WIPE_DOCKER_IMAGES=1 to prune dangling."
fi

printf '\n=== KEPT ===\n'
printf '  llama-server :11434\n'
printf '  ~/models/\n'
printf '  Open WebUI :8080\n'
printf '  SearXNG :8888\n'
printf '  ~/thoma (this repo)\n'

printf '\n=== POST-WIPE CHECK ===\n'
for unit in $EVOX3_JINHUA_UNITS; do
  st="$(systemctl --user is-active "$unit" 2>/dev/null || printf 'not-found')"
  printf '  %s = %s\n' "$unit" "$st"
done
if command -v ss >/dev/null 2>&1; then
  leftover="$(ss -tln | grep -E ':8000 |:5173 |:8002 |:5432 |:7687 ' || true)"
  if [ -n "$leftover" ]; then
    warn "Still listening:"
    printf '%s\n' "$leftover"
  else
    ok "Jinhua ports 8000/5173/8002/5432/7687 are free"
  fi
fi
if wait_for_tcp 127.0.0.1 11434 2; then
  ok "llama-server :11434 still open"
else
  warn "llama-server :11434 not listening (not started by this wipe)"
fi

ok "29_wipe_jinhua.sh complete — Jinhua project destroyed on this machine"
printf '  Docs: docs/JINHUA_FULL_WIPE.md\n'
printf '  Do not run run_all.sh / 02 / 12 again unless you intentionally reinstall Jinhua.\n'
