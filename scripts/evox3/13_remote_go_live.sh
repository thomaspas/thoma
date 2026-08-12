#!/usr/bin/env bash
# Remote go-live: upload sample note, wait for ingest (indexed|failed), Greek chat.
# Run on EVO-X3 over SSH. Do NOT start chat until ingest leaves "parsing".
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl
require_cmd python3

# Prefer local Qwen without long thinking traces (ingest otherwise sticks at parsing).
bash "$SCRIPT_DIR/14_patch_openai_llm_local.sh" || warn "14_patch_openai_llm_local.sh failed — continuing"

API="http://${EVOX3_API_HOST}:${EVOX3_API_PORT}"
SAMPLE_MD="${EVOX3_AI_APPS}/evox3-greek-smoke.md"
DOC_ID="${1:-}"
MAX_WAIT_SEC="${EVOX3_INGEST_WAIT_SEC:-600}"
POLL_SEC="${EVOX3_INGEST_POLL_SEC:-5}"

if [ ! -f "$SAMPLE_MD" ]; then
  mkdir -p "$(dirname "$SAMPLE_MD")"
  cat >"$SAMPLE_MD" <<'EOF'
# EVO-X3 Greek smoke note

Το τοπικό Second Brain τρέχει στο EVO-X3 με LOCAL FULL stack.
Ο χρήστης kiosk είναι ye@evox3.local.
Αυτή η σημείωση υπάρχει για δοκιμή ελληνικής συνομιλίας.
EOF
  ok "Wrote $SAMPLE_MD"
fi

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

if [ -z "$DOC_ID" ]; then
  log "Uploading $SAMPLE_MD"
  UP="$(
    curl -fsS -X POST "${API}/documents/upload" \
      -H "Authorization: Bearer ${TOKEN}" \
      -F "file=@${SAMPLE_MD};type=text/markdown" \
      -F "title=EVO-X3 Greek smoke"
  )"
  printf '%s\n' "$UP"
  DOC_ID="$(printf '%s' "$UP" | python3 -c 'import sys,json; print(json.load(sys.stdin)["document_id"])')"
  ok "document_id=$DOC_ID"
else
  log "Reusing document_id=$DOC_ID"
fi

log "Waiting for ingest (max ${MAX_WAIT_SEC}s). Status stays 'parsing' while local LLM drafts cards."
ELAPSED=0
LAST=""
while [ "$ELAPSED" -lt "$MAX_WAIT_SEC" ]; do
  BODY="$(curl -sS "${API}/documents/${DOC_ID}" -H "Authorization: Bearer ${TOKEN}" || true)"
  ST="$(printf '%s' "$BODY" | python3 -c 'import sys,json
try:
  print(json.load(sys.stdin).get("status",""))
except Exception:
  print("")
' 2>/dev/null || true)"
  ERR="$(printf '%s' "$BODY" | python3 -c 'import sys,json
try:
  print(json.load(sys.stdin).get("error_message") or "")
except Exception:
  print("")
' 2>/dev/null || true)"
  if [ "$ST" != "$LAST" ]; then
    log "status=$ST elapsed=${ELAPSED}s"
    LAST="$ST"
  fi
  case "$ST" in
    indexed)
      ok "Ingest complete (indexed)"
      break
      ;;
    failed)
      warn "Ingest failed: ${ERR}"
      warn "API log tail:"
      journalctl --user -u evox3-jinhua-api.service -n 80 --no-pager 2>/dev/null || true
      exit 1
      ;;
    parsed)
      log "parsed — embedding/graph finalize still running"
      ;;
    parsing|pending|"")
      ;;
    *)
      log "unexpected status=$ST"
      ;;
  esac
  sleep "$POLL_SEC"
  ELAPSED=$((ELAPSED + POLL_SEC))
done

if [ "$ST" != "indexed" ]; then
  warn "Still status=${ST:-unknown} after ${MAX_WAIT_SEC}s"
  warn "Likely local LLM still drafting cards (Qwen 27B is slow) or hung."
  warn "Check: journalctl --user -u evox3-jinhua-api.service -n 100 --no-pager"
  warn "Check llama is free: curl -fsS ${EVOX3_LLM_BASE_URL}/models"
  journalctl --user -u evox3-jinhua-api.service -n 100 --no-pager 2>/dev/null || true
  exit 1
fi

log "Greek chat"
CHAT="$(
  curl -sS -X POST "${API}/assistant/chat" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    -d '{"message":"Ποιος είναι ο kiosk χρήστης στο EVO-X3;","top_k":5}'
)"
printf '%s\n' "$CHAT"
ok "13_remote_go_live.sh complete"
