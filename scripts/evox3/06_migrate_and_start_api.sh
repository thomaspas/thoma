#!/usr/bin/env bash
# Alembic migrate + systemd user unit for Jinhua FastAPI (default :8000).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd systemctl
require_cmd curl

[ -x "$EVOX3_JINHUA_DIR/.venv/bin/python" ] || die "Missing venv — run 04_install_python_deps.sh"
[ -f "$EVOX3_JINHUA_DIR/.env" ] || die "Missing .env — run 03_write_local_env.sh"

cd "$EVOX3_JINHUA_DIR"

log "Checking llama-server at ${EVOX3_LLM_BASE_URL%/v1}/v1/models"
if ! curl -fsS "${EVOX3_LLM_BASE_URL}/models" >/dev/null 2>&1; then
  warn "LLM not reachable at ${EVOX3_LLM_BASE_URL}/models — start llama-server before chatting"
fi

log "Checking embeddings at ${EVOX3_EMBED_BASE_URL%/v1}/health"
if ! curl -fsS "http://127.0.0.1:${EVOX3_BGE_PORT}/health" >/dev/null 2>&1; then
  die "Embeddings server not healthy on :${EVOX3_BGE_PORT} — run 05_start_bge_m3_server.sh"
fi

# Fresh installs must bootstrap baseline tables via SQLAlchemy metadata first.
# Alembic revisions (0001+) only add columns to existing tables (see init_db()).
log "Bootstrapping DB via secondbrain.db.session.init_db() (create_all + alembic)"
.venv/bin/python - <<'PY'
from secondbrain.db.session import init_db

init_db()
print("INIT_DB_OK")
PY

UNIT_DIR="$(user_systemd_dir)"
UNIT_PATH="$UNIT_DIR/evox3-jinhua-api.service"

cat > "$UNIT_PATH" <<EOF
[Unit]
Description=EVO-X3 Jinhua SecondBrain API (uvicorn :${EVOX3_API_PORT})
After=network-online.target docker.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${EVOX3_JINHUA_DIR}
EnvironmentFile=${EVOX3_JINHUA_DIR}/.env
ExecStart=${EVOX3_JINHUA_DIR}/.venv/bin/python -m uvicorn apps.api.main:app --host ${EVOX3_API_HOST} --port ${EVOX3_API_PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

reload_user_systemd
enable_linger_hint

# Qwen thinking can stall ingest at status=parsing; patch before API start.
bash "$SCRIPT_DIR/14_patch_openai_llm_local.sh" || warn "14 LLM patch skipped"

systemctl --user enable --now evox3-jinhua-api.service

log "Waiting for API docs on :${EVOX3_API_PORT}"
READY=0
for _ in $(seq 1 60); do
  if curl -fsS "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/docs" >/dev/null 2>&1 \
    || curl -fsS "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/openapi.json" >/dev/null 2>&1 \
    || curl -fsS "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/health" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" -ne 1 ]; then
  warn "API health timed out. Recent logs:"
  journalctl --user -u evox3-jinhua-api.service -n 80 --no-pager || true
  die "Jinhua API did not become ready"
fi

if [ -f scripts/check_providers.py ]; then
  log "Running scripts/check_providers.py"
  .venv/bin/python scripts/check_providers.py || warn "check_providers.py reported issues (LLM/embeddings)"
fi

ok "06_migrate_and_start_api.sh complete — API http://${EVOX3_API_HOST}:${EVOX3_API_PORT}"
