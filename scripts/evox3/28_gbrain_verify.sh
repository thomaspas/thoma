#!/usr/bin/env bash
# Verify ANGELICA GBrain Level 5 on EVO-X3. Paste this output into Cloud chat.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

ensure_bun_on_path
export GBRAIN_NO_ONBOARD_NUDGE=1

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

printf '\n=== ANGELICA GBRAIN LEVEL 5 VERIFY ===\n'
printf 'workspace=%s\n' "$EVOX3_GBRAIN_HOME"
printf 'unit=%s\n' "$EVOX3_GBRAIN_UNIT"
printf 'http=%s:%s\n' "$EVOX3_GBRAIN_HTTP_BIND" "$EVOX3_GBRAIN_HTTP_PORT"
printf 'Paste this output into the Cloud agent chat.\n\n'

printf '=== 1) PATH / bun / gbrain binary ===\n'
printf 'PATH=%s\n' "$PATH"
if command -v bun >/dev/null 2>&1; then
  check_ok "bun $(bun --version) at $(command -v bun)"
else
  check_fail "bun not on PATH — run 27_gbrain_angelica.sh"
fi

GBRAIN_BIN="$(command -v gbrain 2>/dev/null || true)"
if [ -n "$GBRAIN_BIN" ]; then
  check_ok "gbrain at $GBRAIN_BIN"
  printf -- '----- gbrain --version -----\n'
  gbrain --version || check_fail "gbrain --version failed"
  printf -- '----- which -a gbrain -----\n'
  which -a gbrain 2>/dev/null || true
else
  check_fail "gbrain not on PATH"
fi

printf '\n=== 2) npm-shadow gbrain (unrelated package) ===\n'
SHADOW=0
if command -v npm >/dev/null 2>&1; then
  NPM_ROOT="$(npm root -g 2>/dev/null || true)"
  if [ -n "$NPM_ROOT" ] && [ -d "${NPM_ROOT}/gbrain" ]; then
    SHADOW=1
    warn "npm global 'gbrain' at ${NPM_ROOT}/gbrain — NOT Garry Tan GBrain"
    warn "Fix: npm uninstall -g gbrain && bun install -g github:garrytan/gbrain"
  fi
fi
case "$GBRAIN_BIN" in
  *node_modules/gbrain*|*npm/gbrain*)
    SHADOW=1
    warn "PATH gbrain looks like npm-shadow: $GBRAIN_BIN"
    ;;
esac
if [ "$SHADOW" -eq 0 ]; then
  check_ok "No npm-shadow gbrain on PATH / npm root -g"
else
  check_fail "npm-shadow gbrain detected — uninstall the npm package"
fi

printf '\n=== 3) gbrain doctor ===\n'
if [ -n "$GBRAIN_BIN" ]; then
  printf -- '----- gbrain doctor -----\n'
  if gbrain doctor; then
    check_ok "gbrain doctor exited 0"
  elif grep -Eq 'embedding_disabled|no-embedding' "$HOME/.gbrain/config.json" 2>/dev/null; then
    warn "gbrain doctor non-zero — allowed for keyless --no-embedding. See output above."
    check_ok "gbrain doctor ran (keyless warnings allowed)"
  else
    check_fail "gbrain doctor exited non-zero"
  fi
else
  check_fail "skip doctor (no gbrain binary)"
fi

printf '\n=== 4) identity + workspace ===\n'
if [ "$(basename "$EVOX3_GBRAIN_HOME")" = "thoma" ]; then
  check_fail "workspace must not be ~/thoma (got $EVOX3_GBRAIN_HOME)"
fi
if [ -d "$EVOX3_GBRAIN_HOME" ]; then
  check_ok "workspace dir $EVOX3_GBRAIN_HOME"
else
  check_fail "missing workspace $EVOX3_GBRAIN_HOME"
fi
for f in SOUL.md USER.md MEMORY.md; do
  if [ -f "$EVOX3_GBRAIN_HOME/$f" ] && grep -q 'ANGELICA' "$EVOX3_GBRAIN_HOME/$f"; then
    check_ok "identity $f contains ANGELICA"
  else
    check_fail "identity $f missing ANGELICA ($EVOX3_GBRAIN_HOME/$f)"
  fi
done

printf '\n=== 5) systemd unit %s ===\n' "$EVOX3_GBRAIN_UNIT"
if systemctl --user is-active --quiet "$EVOX3_GBRAIN_UNIT" 2>/dev/null; then
  check_ok "$EVOX3_GBRAIN_UNIT is active"
else
  check_fail "$EVOX3_GBRAIN_UNIT is not active"
  systemctl --user status "$EVOX3_GBRAIN_UNIT" --no-pager -l 2>/dev/null | head -n 40 || true
fi
if systemctl --user is-enabled --quiet "$EVOX3_GBRAIN_UNIT" 2>/dev/null; then
  check_ok "$EVOX3_GBRAIN_UNIT is enabled"
else
  check_fail "$EVOX3_GBRAIN_UNIT is not enabled"
fi

printf '\n=== 6) HTTP serve (always-on) ===\n'
if wait_for_tcp "$EVOX3_GBRAIN_HTTP_BIND" "$EVOX3_GBRAIN_HTTP_PORT" 3; then
  check_ok "tcp ${EVOX3_GBRAIN_HTTP_BIND}:${EVOX3_GBRAIN_HTTP_PORT} open"
  if command -v curl >/dev/null 2>&1; then
    code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://${EVOX3_GBRAIN_HTTP_BIND}:${EVOX3_GBRAIN_HTTP_PORT}/admin" 2>/dev/null || printf '000')"
    printf '  GET /admin HTTP %s\n' "$code"
    case "$code" in
      200|301|302|307|308|401|403) check_ok "HTTP admin responded ($code)" ;;
      *) warn "HTTP /admin unexpected $code (unit may still be starting)" ;;
    esac
  fi
else
  check_fail "tcp ${EVOX3_GBRAIN_HTTP_BIND}:${EVOX3_GBRAIN_HTTP_PORT} closed"
fi

printf '\n=== 7) kept hardware services (not Jinhua) ===\n'
if wait_for_tcp 127.0.0.1 11434 2; then
  check_ok "llama-server :11434 open"
else
  warn "llama-server :11434 closed (kept service; start it separately if chat needed)"
fi
if wait_for_tcp 127.0.0.1 8080 2; then
  ok "Open WebUI :8080 open"
else
  log "Open WebUI :8080 not listening (optional)"
fi
if wait_for_tcp 127.0.0.1 8888 2; then
  ok "SearXNG :8888 open"
else
  log "SearXNG :8888 not listening (optional)"
fi

printf '\n=== 8) Jinhua units should be inactive ===\n'
for unit in $EVOX3_JINHUA_UNITS; do
  if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
    warn "$unit still active — re-run 26_retire_jinhua_kiosk.sh"
  else
    ok "$unit inactive (expected)"
  fi
done

printf '\n=== RESULT ===\n'
printf 'pass=%s fail=%s\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
  ok "GBRAIN VERIFY OK"
  printf 'Cursor MCP: copy docs/mcp_cursor_gbrain.json.example then restart MCP.\n'
  exit 0
fi
warn "GBRAIN VERIFY FAILED — paste this output in chat"
exit 1
