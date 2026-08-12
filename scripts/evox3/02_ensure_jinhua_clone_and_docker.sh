#!/usr/bin/env bash
# Clone IncubativeSecondBrain (if needed) and ensure Docker infra is Up.
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

# Basic readiness waits
log "Waiting for Postgres on localhost:5432"
for _ in $(seq 1 60); do
  if (echo >/dev/tcp/127.0.0.1/5432) >/dev/null 2>&1; then
    ok "Postgres port open"
    break
  fi
  sleep 1
done

log "Waiting for Neo4j bolt on localhost:7687"
for _ in $(seq 1 60); do
  if (echo >/dev/tcp/127.0.0.1/7687) >/dev/null 2>&1; then
    ok "Neo4j port open"
    break
  fi
  sleep 1
done

ok "02_ensure_jinhua_clone_and_docker.sh complete"
