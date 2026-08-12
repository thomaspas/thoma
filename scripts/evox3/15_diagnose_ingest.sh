#!/usr/bin/env bash
# Diagnose stuck ingest (status=parsing) and optionally force sync re-ingest.
# Usage:
#   ./scripts/evox3/15_diagnose_ingest.sh <document_id>
#   EVOX3_FORCE_SYNC_INGEST=1 ./scripts/evox3/15_diagnose_ingest.sh <document_id>
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl
require_cmd python3

DOC_ID="${1:-}"
[ -n "$DOC_ID" ] || die "Usage: $0 <document_id>"

API="http://${EVOX3_API_HOST}:${EVOX3_API_PORT}"

log "=== document status ==="
TOKEN="$(
  curl -fsS -X POST "${API}/auth/login" \
    -H 'Content-Type: application/json' \
    -d "$(python3 - <<PY
import json
print(json.dumps({"email": """${EVOX3_LOCAL_EMAIL}""", "password": """${EVOX3_LOCAL_PASSWORD}"""}))
PY
)" | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])'
)"
curl -sS "${API}/documents/${DOC_ID}" -H "Authorization: Bearer ${TOKEN}"
echo

log "=== LLM probe (60s max, /no_think) ==="
MODEL="$(curl -fsS --max-time 5 "${EVOX3_LLM_BASE_URL}/models" | python3 -c 'import sys,json; d=json.load(sys.stdin); print((d.get("data") or [{}])[0].get("id",""))')"
log "model=$MODEL"
curl -sS --max-time 60 "${EVOX3_LLM_BASE_URL}/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "$(MODEL="$MODEL" python3 - <<'PY'
import json, os
print(json.dumps({
  "model": os.environ["MODEL"],
  "messages": [
    {"role": "system", "content": "Reply with JSON only."},
    {"role": "user", "content": "Return {\"ok\": true}\n/no_think"},
  ],
  "temperature": 0.1,
  "max_tokens": 64,
  "chat_template_kwargs": {"enable_thinking": False},
}))
PY
)" || warn "LLM probe failed/timed out — llama may be busy or hung"
echo

log "=== API journal (last 80) ==="
journalctl --user -u evox3-jinhua-api.service -n 80 --no-pager 2>/dev/null || true

if [ "${EVOX3_FORCE_SYNC_INGEST:-0}" = "1" ]; then
  [ -x "$EVOX3_JINHUA_DIR/.venv/bin/python" ] || die "Missing venv python"
  log "=== sync ingest_document (foreground, 180s timeout) ==="
  (
    cd "$EVOX3_JINHUA_DIR"
    timeout 180 .venv/bin/python - <<PY
from apps.worker.tasks.ingest import ingest_document
print(ingest_document("$DOC_ID"))
PY
  ) || warn "sync ingest failed or timed out — see traceback above"
  curl -sS "${API}/documents/${DOC_ID}" -H "Authorization: Bearer ${TOKEN}"
  echo
fi

ok "15_diagnose_ingest.sh complete"
