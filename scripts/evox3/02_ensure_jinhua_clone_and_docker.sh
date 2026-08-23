#!/usr/bin/env bash
# Clone IncubativeSecondBrain (if needed) and ensure Docker infra is Up.
# Also installs a user systemd unit so compose comes back after reboot.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd git
require_cmd docker

# Evidence 2026-08-23: operator Ctrl+C during image pull left Postgres CLOSED.
_on_interrupt() {
  warn "Interrupted during docker setup — images may be incomplete."
  warn "Re-run WITHOUT Ctrl+C: ./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh"
  exit 130
}
trap _on_interrupt INT TERM

ensure_dir "$EVOX3_AI_APPS"

if [ -d "$EVOX3_JINHUA_DIR/.git" ]; then
  ok "Jinhua repo already present: $EVOX3_JINHUA_DIR"
else
  log "Cloning $EVOX3_JINHUA_REPO -> $EVOX3_JINHUA_DIR"
  git clone --depth 1 "$EVOX3_JINHUA_REPO" "$EVOX3_JINHUA_DIR"
fi

cd "$EVOX3_JINHUA_DIR"
log "Starting docker compose (Postgres + Neo4j + MinIO)"
log "First run may download large images (hundreds of MB) — do NOT Ctrl+C"

compose_ok=0
for attempt in 1 2 3; do
  log "docker compose up -d (attempt ${attempt}/3)"
  if docker compose up -d; then
    compose_ok=1
    break
  fi
  warn "docker compose failed — retrying in 15s"
  sleep 15
done
[ "$compose_ok" = "1" ] || die "docker compose up -d failed after 3 attempts"

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Persist compose across reboot (user linger + default.target).
install_jinhua_docker_unit

# Basic readiness waits (pull+start can exceed 60s on slow Wi-Fi)
log "Waiting for Postgres on localhost:5432"
if wait_for_tcp 127.0.0.1 5432 180; then
  ok "Postgres port open"
else
  die "Postgres did not open :5432 — check: docker compose ps && docker compose logs"
fi

log "Waiting for Neo4j bolt on localhost:7687"
if wait_for_tcp 127.0.0.1 7687 120; then
  ok "Neo4j port open"
else
  warn "Neo4j :7687 not open yet — graph features may fail until it is"
fi

trap - INT TERM
ok "02_ensure_jinhua_clone_and_docker.sh complete"
