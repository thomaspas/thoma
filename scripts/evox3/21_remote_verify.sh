#!/usr/bin/env bash
# Remote-only verification for SSH operators (no physical visit to EVO-X3 screen).
# Usage:
#   ./scripts/evox3/21_remote_verify.sh
#   EVOX3_REMOTE_VERIFY_CHAT=1 ./scripts/evox3/21_remote_verify.sh  # includes 13 go-live
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl
require_cmd python3

PASS=0
FAIL=0

check_ok() {
  ok "$1"
  PASS=$((PASS + 1))
}

check_fail() {
  warn "$1"
  FAIL=$((FAIL + 1))
}

printf '\n=== EVO-X3 REMOTE VERIFY (SSH operator) ===\n'
printf 'build=2026-08-12-kiosk-v3 (deep /proc scan + gnome env import)\n'
printf 'Operator runs from another machine — no screen visit required.\n\n'

#region agent log
if [ -x "$SCRIPT_DIR/22_operator_context_check.sh" ]; then
  bash "$SCRIPT_DIR/22_operator_context_check.sh" || true
fi
#endregion

printf '=== 1) smoke baseline (09) ===\n'
if bash "$SCRIPT_DIR/09_smoke_check.sh"; then
  check_ok "09_smoke_check.sh passed"
else
  check_fail "09_smoke_check.sh failed — fix stack before remote HTML/process checks"
fi

printf '\n=== 2) web HTML brand (:5173) ===\n'
WEB_HTML="$(curl -fsS --max-time 10 "http://127.0.0.1:${EVOX3_WEB_PORT}/" 2>/dev/null || true)"
if [ -z "$WEB_HTML" ]; then
  check_fail "Could not fetch http://127.0.0.1:${EVOX3_WEB_PORT}/"
else
  if printf '%s' "$WEB_HTML" | grep -q "$EVOX3_BRAND_NAME"; then
    check_ok "HTML contains ${EVOX3_BRAND_NAME}"
  else
    check_fail "HTML missing ${EVOX3_BRAND_NAME} — run ./scripts/evox3/16_brand_angelica.sh"
  fi
  if printf '%s' "$WEB_HTML" | grep -Eiq 'Register|Login|AuthScreen'; then
    check_fail "HTML still shows auth UI — run ./scripts/evox3/11_skip_auth_ui.sh"
  else
    check_ok "HTML has no Register/Login/AuthScreen markers"
  fi
fi

printf '\n=== 3) page title ===\n'
TITLE="$(printf '%s' "$WEB_HTML" | python3 -c '
import re, sys
html = sys.stdin.read()
m = re.search(r"<title[^>]*>([^<]+)</title>", html, re.I)
print(m.group(1).strip() if m else "")
' 2>/dev/null || true)"
if [ -n "$TITLE" ] && printf '%s' "$TITLE" | grep -q "$EVOX3_BRAND_NAME"; then
  check_ok "page title contains ${EVOX3_BRAND_NAME}: ${TITLE}"
else
  check_fail "page title missing ${EVOX3_BRAND_NAME} (got: ${TITLE:-empty})"
fi

printf '\n=== 4) kiosk process args ===\n'

#region agent log
_dbg_verify() {
  local hid="$1" msg="$2" data="${3:-{}}"
  local log_path="${THOMA_DEBUG_LOG:-/tmp/thoma-debug-f7f922.ndjson}"
  python3 -c "import json,time; open('${log_path}','a').write(json.dumps({'sessionId':'f7f922','hypothesisId':'${hid}','location':'21_remote_verify.sh','message':'${msg}','data':${data},'timestamp':int(time.time()*1000)})+'\n')" 2>/dev/null || true
}
#endregion

_kiosk_port_visible() {
  kiosk_references_web_port
}

PROC_LINES="$(kiosk_proc_snapshot)"
_dbg_verify "H5" "kiosk snapshot before relaunch" "{\"deep_port\":$(_kiosk_port_visible && echo true || echo false)}"

# Web UI healthy but kiosk stale/missing — auto-relaunch once (SSH operator, no screen visit).
if ! _kiosk_port_visible; then
  if [ -n "$WEB_HTML" ] && printf '%s' "$WEB_HTML" | grep -q "$EVOX3_BRAND_NAME"; then
    log "Web UI OK on :${EVOX3_WEB_PORT} but kiosk not on web port — auto-running 10_relaunch_kiosk.sh"
    if bash "$SCRIPT_DIR/10_relaunch_kiosk.sh"; then
      _dbg_verify "H1" "10_relaunch_kiosk exit" "{\"ok\":true}"
    else
      _dbg_verify "H1" "10_relaunch_kiosk exit" "{\"ok\":false}"
    fi
    log "Waiting up to 45s for kiosk browser on :${EVOX3_WEB_PORT} (flatpak may start slowly)"
    if wait_for_kiosk_web_port 45; then
      _dbg_verify "H5" "kiosk port visible after wait" "{\"ok\":true}"
    else
      _dbg_verify "H5" "kiosk port visible after wait" "{\"ok\":false}"
    fi
    PROC_LINES="$(kiosk_proc_snapshot)"
  fi
fi

if [ -z "$PROC_LINES" ] && ! _kiosk_port_visible; then
  check_fail "No chromium/kiosk process — run ./scripts/evox3/10_relaunch_kiosk.sh"
elif _kiosk_port_visible; then
  check_ok "browser process references :${EVOX3_WEB_PORT} (pgrep or /proc scan)"
else
  check_fail "browser process missing :${EVOX3_WEB_PORT} — run ./scripts/evox3/10_relaunch_kiosk.sh"
  if [ -f /tmp/evox3-jinhua-kiosk.log ]; then
    warn "Kiosk log tail (paste if debugging):"
    tail -n 20 /tmp/evox3-jinhua-kiosk.log >&2 || true
  fi
fi

PROC_LINES="$(kiosk_proc_snapshot)"
if printf '%s\n' "$PROC_LINES" | grep -q ":${EVOX3_API_PORT}"; then
  check_fail "browser process still references API :${EVOX3_API_PORT} (wrong target)"
else
  check_ok "browser process does not target API :${EVOX3_API_PORT}"
fi

if [ "${EVOX3_REMOTE_VERIFY_CHAT:-0}" = "1" ]; then
  printf '\n=== 5) Greek chat go-live (13) ===\n'
  if bash "$SCRIPT_DIR/13_remote_go_live.sh"; then
    check_ok "13_remote_go_live.sh passed"
  else
    check_fail "13_remote_go_live.sh failed"
  fi
else
  log "Skipping chat E2E (set EVOX3_REMOTE_VERIFY_CHAT=1 to include 13_remote_go_live.sh)"
fi

printf '\n=== remote verify result: %s pass / %s fail ===\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  printf '\nPaste this block to Cursor for debugging.\n'
  exit 1
fi

printf '\n=== REMOTE VERIFY OK — no physical visit needed ===\n'
printf 'Paste this block to Cursor if sharing status.\n'
ok "21_remote_verify.sh complete"
