#!/usr/bin/env bash
# curl-only smoke: login + upload sample markdown (no browser required).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl
require_cmd python3

API="http://${EVOX3_API_HOST}:${EVOX3_API_PORT}"
SAMPLE_MD="${EVOX3_AI_APPS}/evox3-capture-demo.md"

mkdir -p "$(dirname "$SAMPLE_MD")"
cat >"$SAMPLE_MD" <<EOF
# ANGELICA browser capture demo

Simulated web capture upload from script 19_demo_capture.sh.
Source: https://example.com/angelica-demo
Captured: $(date -u +%Y-%m-%dT%H:%M:%SZ)

Το extension ANGELICA Capture στέλνει σελίδες στο τοπικό API.
EOF

log "Login as ${EVOX3_LOCAL_EMAIL}"
TOKEN="$(
  curl -fsS -X POST "${API}/auth/login" \
    -H 'Content-Type: application/json' \
    -d "$(python3 - <<PY
import json
print(json.dumps({"email": """${EVOX3_LOCAL_EMAIL}""", "password": """${EVOX3_LOCAL_PASSWORD}"""}))
PY
)" | python3 -c 'import sys,json; print(json.load(sys.stdin)["access_token"])'
)"

log "Uploading $SAMPLE_MD (simulated extension capture)"
UP="$(
  curl -fsS -X POST "${API}/documents/upload" \
    -H "Authorization: Bearer ${TOKEN}" \
    -F "file=@${SAMPLE_MD};type=text/markdown" \
    -F "title=ANGELICA capture demo"
)"
printf '%s\n' "$UP"
DOC_ID="$(printf '%s' "$UP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["document_id"])')"
ok "document_id=$DOC_ID (ingest runs in background — poll with 15_diagnose_ingest.sh if needed)"
ok "19_demo_capture.sh complete"
