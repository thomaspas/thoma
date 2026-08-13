#!/usr/bin/env bash
# Detect operator context — avoid unnecessary self-SSH when already on EVO-X3.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

HOST="$(hostname -s 2>/dev/null || hostname)"
SSH_CLIENT_VAL="${SSH_CLIENT:-}"
ON_EVOX3=0
if printf '%s' "$HOST" | grep -qi 'EVO-X3'; then
  ON_EVOX3=1
fi

#region agent log
_ts() { date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))'; }
_dbg() {
  local msg="$1" hid="$2" extra="${3:-{}}"
  local ts line
  # Call _ts as a function; '${_ts}' under set -u is an unbound variable.
  ts="$(_ts)"
  line="$(python3 -c "import json,os; print(json.dumps({'sessionId':'f7f922','hypothesisId':'$hid','location':'22_operator_context_check.sh','message':'$msg','data':$extra,'timestamp':int('${ts}')}))" 2>/dev/null || echo '{}')"
  printf '%s\n' "$line" >&2
  if [ -n "${THOMA_DEBUG_LOG:-}" ] && [ -w "$(dirname "$THOMA_DEBUG_LOG")" ] 2>/dev/null; then
    printf '%s\n' "$line" >>"$THOMA_DEBUG_LOG"
  fi
}
_dbg "operator context" "H1" "{\"hostname\":\"$HOST\",\"pwd\":\"$(pwd)\",\"ssh_client\":\"${SSH_CLIENT_VAL:-local}\",\"on_evox3\":$ON_EVOX3}"
#endregion

printf '\n=== OPERATOR CONTEXT ===\n'
printf 'hostname=%s\n' "$HOST"
printf 'pwd=%s\n' "$(pwd)"
printf 'ssh_client=%s\n' "${SSH_CLIENT_VAL:-<none — local shell>}"
printf 'on_evox3=%s\n' "$ON_EVOX3"

if [ "$ON_EVOX3" -eq 1 ] && [ -z "$SSH_CLIENT_VAL" ]; then
  warn "You are ALREADY on EVO-X3 in a local shell — do NOT ssh to 192.168.1.8."
  warn "Run ./scripts/evox3/21_remote_verify.sh directly from ~/thoma (no nested ssh)."
  ok "Correct next step: cd ~/thoma && ./scripts/evox3/21_remote_verify.sh"
elif [ "$ON_EVOX3" -eq 1 ] && [ -n "$SSH_CLIENT_VAL" ]; then
  ok "SSH session into EVO-X3 from ${SSH_CLIENT_VAL%% *} — run 21_remote_verify.sh here."
elif [ -n "$SSH_CLIENT_VAL" ]; then
  ok "Remote SSH session active — good for remote operator workflow."
else
  warn "Not on EVO-X3 hostname — use: ssh thomas-pashoulas@192.168.1.8"
  warn "Ensure Gaming-7 has ssh-copy-id to EVO-X3 (not EVO-X3 to itself)."
  warn "Simple Browser http://127.0.0.1:5173 HERE = ERR_CONNECTION_REFUSED (Vite is on EVO)."
  warn "Fix: Remote-SSH Connect to Host, Ports forward 5173, then ./scripts/evox3/27_web_ui_preview.sh"
fi
