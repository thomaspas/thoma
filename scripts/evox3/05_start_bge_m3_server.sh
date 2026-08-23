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

log "Installing sentence-transformers + fastapi stack (can take many minutes — pip torch)"
log "After that, first service start downloads HF model: ${EVOX3_EMBED_MODEL:-BAAI/bge-m3}"
pip_install "$EVOX3_BGE_DIR/.venv/bin/pip" --upgrade pip setuptools wheel
log "pip installing torch + sentence-transformers (large) ..."
pip_install "$EVOX3_BGE_DIR/.venv/bin/pip" \
  "sentence-transformers>=3.0.0" \
  "fastapi>=0.110" \
  "uvicorn[standard]>=0.27" \
  "pydantic>=2.0" \
  "torch" \
  "huggingface_hub"
ok "pip deps installed — next: enable unit (HF model ${EVOX3_EMBED_MODEL} on first /health)"

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

# CPU + first HF download of BAAI/bge-m3 often exceeds 6 minutes (05 used to die here).
WAIT_LOOPS="${EVOX3_BGE_HEALTH_LOOPS:-600}"
WAIT_SLEEP="${EVOX3_BGE_HEALTH_SLEEP:-3}"
log "Waiting for embeddings health on :${EVOX3_BGE_PORT} (up to $((WAIT_LOOPS * WAIT_SLEEP))s — model load is slow on CPU)"
READY=0
for i in $(seq 1 "$WAIT_LOOPS"); do
  code="$(curl -sS -o /tmp/evox3-bge-health.json -w '%{http_code}' --max-time 3 "http://127.0.0.1:${EVOX3_BGE_PORT}/health" 2>/dev/null || echo 000)"
  if [ "$code" = "200" ] && grep -q '"status"[[:space:]]*:[[:space:]]*"ok"' /tmp/evox3-bge-health.json 2>/dev/null; then
    READY=1
    break
  fi
  if [ $((i % 20)) -eq 0 ]; then
    log "still waiting for bge-m3 ready (http=${code}, ${i}/${WAIT_LOOPS}) — journalctl --user -u evox3-bge-m3 -n 5"
  fi
  sleep "$WAIT_SLEEP"
done

if [ "$READY" -ne 1 ]; then
  warn "Health check timed out. Recent logs:"
  journalctl --user -u evox3-bge-m3.service -n 80 --no-pager || true
  die "bge-m3 server did not become healthy"
fi

curl -fsS "http://127.0.0.1:${EVOX3_BGE_PORT}/health"
echo
ok "05_start_bge_m3_server.sh complete — embeddings at ${EVOX3_EMBED_BASE_URL}"
