#!/usr/bin/env bash
# Install local bge-m3 OpenAI-compatible server and enable systemd user unit on :8002.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3
require_cmd systemctl

ensure_dir "$EVOX3_BGE_DIR"
cp -f "$SCRIPT_DIR/bge_m3_server.py" "$EVOX3_BGE_DIR/bge_m3_server.py"
chmod +x "$EVOX3_BGE_DIR/bge_m3_server.py"

if [ ! -x "$EVOX3_BGE_DIR/.venv/bin/python" ]; then
  log "Creating bge-m3 venv"
  python3 -m venv "$EVOX3_BGE_DIR/.venv"
fi

log "Installing sentence-transformers + fastapi stack (HF model downloads on first start)"
pip_install "$EVOX3_BGE_DIR/.venv/bin/pip" --upgrade pip setuptools wheel
pip_install "$EVOX3_BGE_DIR/.venv/bin/pip" \
  "sentence-transformers>=3.0.0" \
  "fastapi>=0.110" \
  "uvicorn[standard]>=0.27" \
  "pydantic>=2.0" \
  "torch" \
  "huggingface_hub"

UNIT_DIR="$(user_systemd_dir)"
UNIT_PATH="$UNIT_DIR/evox3-bge-m3.service"

cat > "$UNIT_PATH" <<EOF
[Unit]
Description=EVO-X3 local BAAI/bge-m3 OpenAI-compatible embeddings (:${EVOX3_BGE_PORT})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${EVOX3_BGE_DIR}
Environment=EVOX3_EMBED_MODEL=${EVOX3_EMBED_MODEL}
Environment=EVOX3_BGE_HOST=127.0.0.1
Environment=EVOX3_BGE_PORT=${EVOX3_BGE_PORT}
Environment=EVOX3_BGE_DEVICE=cpu
Environment=HF_HOME=${HOME}/.cache/huggingface
ExecStart=${EVOX3_BGE_DIR}/.venv/bin/python ${EVOX3_BGE_DIR}/bge_m3_server.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

reload_user_systemd
enable_linger_hint
systemctl --user enable --now evox3-bge-m3.service

log "Waiting for embeddings health on :${EVOX3_BGE_PORT}"
READY=0
for _ in $(seq 1 180); do
  if curl -fsS "http://127.0.0.1:${EVOX3_BGE_PORT}/health" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 2
done

if [ "$READY" -ne 1 ]; then
  warn "Health check timed out. Recent logs:"
  journalctl --user -u evox3-bge-m3.service -n 80 --no-pager || true
  die "bge-m3 server did not become healthy"
fi

curl -fsS "http://127.0.0.1:${EVOX3_BGE_PORT}/health"
echo
ok "05_start_bge_m3_server.sh complete — embeddings at ${EVOX3_EMBED_BASE_URL}"
