#!/usr/bin/env bash
# Clone IncubativeSecondBrain (if needed) and ensure Docker infra is Up.
# Also installs a user systemd unit so compose comes back after reboot.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd git
require_cmd docker

ensure_dir "$EVOX3_AI_APPS"

if [ -d "$EVOX3_JINHUA_DIR/.git" ]; then
  ok "Jinhua repo already present: $EVOX3_JINHUA_DIR"
else
  log "Cloning $EVOX3_JINHUA_REPO -> $EVOX3_JINHUA_DIR"
  git clone --depth 1 "$EVOX3_JINHUA_REPO" "$EVOX3_JINHUA_DIR"
fi

cd "$EVOX3_JINHUA_DIR"
log "Starting docker compose (Postgres + Neo4j + MinIO)"
docker compose up -d
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Persist compose across reboot (user linger + default.target).
install_jinhua_docker_unit

# Basic readiness waits
log "Waiting for Postgres on localhost:5432"
if wait_for_tcp 127.0.0.1 5432 60; then
  ok "Postgres port open"
else
  die "Postgres did not open :5432 — check: docker compose ps && docker compose logs"
fi

log "Waiting for Neo4j bolt on localhost:7687"
if wait_for_tcp 127.0.0.1 7687 60; then
  ok "Neo4j port open"
else
  warn "Neo4j :7687 not open yet — graph features may fail until it is"
fi

ok "02_ensure_jinhua_clone_and_docker.sh complete"
