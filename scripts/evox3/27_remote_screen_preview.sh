#!/usr/bin/env bash
# Capture the EVO-X3 physical display and serve it on 127.0.0.1:5174
# for Cursor Simple Browser (opt-in; not a substitute for 21_remote_verify).
# Usage (run ON EVO-X3 — Remote SSH terminal or ssh from Gaming-7):
#   ./scripts/evox3/27_remote_screen_preview.sh
#   ./scripts/evox3/27_remote_screen_preview.sh status
#   ./scripts/evox3/27_remote_screen_preview.sh stop
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3
require_cmd curl

SERVER_PY="$SCRIPT_DIR/screen_preview_server.py"
STATE_DIR="${EVOX3_SCREEN_PREVIEW_DIR:-/tmp/evox3-screen-preview}"
PID_FILE="${EVOX3_SCREEN_PREVIEW_PID:-$STATE_DIR/server.pid}"
LOG_FILE="${EVOX3_SCREEN_PREVIEW_LOG:-/tmp/evox3-screen-preview.log}"
BIND="${EVOX3_SCREEN_PREVIEW_BIND:-127.0.0.1}"
PORT="${EVOX3_SCREEN_PREVIEW_PORT:-5174}"
URL="http://${BIND}:${PORT}/"
ACTION="${1:-start}"

preview_pid() {
  if [ -f "$PID_FILE" ]; then
    cat "$PID_FILE" 2>/dev/null || true
  fi
}

preview_running() {
  local pid
  pid="$(preview_pid)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

health_ok() {
  curl -fsS --max-time 3 "${URL}health" >/dev/null 2>&1
}

cmd_status() {
  printf '\n=== EVO-X3 SCREEN PREVIEW ===\n'
  printf 'url=%s\n' "$URL"
  printf 'pid_file=%s\n' "$PID_FILE"
  printf 'log=%s\n' "$LOG_FILE"
  printf 'DISPLAY=%s WAYLAND_DISPLAY=%s\n' "${DISPLAY:-}" "${WAYLAND_DISPLAY:-}"
  if preview_running; then
    ok "server pid $(preview_pid) is running"
  else
    warn "server is not running"
  fi
  if health_ok; then
    ok "health ${URL}health OK"
    curl -fsS --max-time 3 "${URL}health" || true
    printf '\n'
  else
    warn "health endpoint not reachable"
  fi
}

cmd_stop() {
  local pid
  pid="$(preview_pid)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    log "Stopping screen preview pid $pid"
    kill "$pid" 2>/dev/null || true
    sleep 1
    kill -9 "$pid" 2>/dev/null || true
    ok "Stopped screen preview"
  else
    log "Screen preview not running"
  fi
  rm -f "$PID_FILE"
}

cmd_start() {
  setup_local_graphical_env

  if [ ! -f "$SERVER_PY" ]; then
    die "Missing $SERVER_PY"
  fi

  if [ -z "${WAYLAND_DISPLAY:-}" ] && { [ -z "${XAUTHORITY:-}" ] || [ ! -f "${XAUTHORITY}" ]; }; then
    die "No logged-in desktop session (no WAYLAND_DISPLAY / XAUTHORITY). Same as kiosk: need GNOME logged in on EVO-X3, then ./scripts/evox3/10_relaunch_kiosk.sh"
  fi

  ensure_dir "$STATE_DIR"

  if preview_running && health_ok; then
    ok "Already running at $URL"
    printf '\nCursor: Command Palette → Simple Browser: Show → %s\n' "$URL"
    printf 'ANGELICA UI: http://127.0.0.1:%s/\n' "$EVOX3_WEB_PORT"
    printf 'Stop: ./scripts/evox3/27_remote_screen_preview.sh stop\n'
    return 0
  fi

  if preview_running; then
    warn "Stale/unhealthy pid — restarting"
    cmd_stop
  fi

  if curl -fsS --max-time 1 "${URL}health" >/dev/null 2>&1; then
    die "Port ${PORT} already in use by another process"
  fi

  log "Starting screen preview on ${BIND}:${PORT}"
  export EVOX3_SCREEN_PREVIEW_BIND="$BIND"
  export EVOX3_SCREEN_PREVIEW_PORT="$PORT"
  export EVOX3_SCREEN_PREVIEW_DIR="$STATE_DIR"
  nohup python3 "$SERVER_PY" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  sleep 1

  if ! preview_running; then
    warn "Server exited — log tail:"
    tail -n 30 "$LOG_FILE" >&2 || true
    die "Failed to start screen preview"
  fi

  local i
  for i in $(seq 1 10); do
    if health_ok; then
      break
    fi
    sleep 0.3
  done

  cmd_status
  if ! health_ok; then
    warn "Server up but /health not OK yet — first capture may still be failing"
    warn "Paste: tail -n 40 $LOG_FILE"
  fi

  printf '\n=== Cursor Simple Browser ===\n'
  printf '  1) Command Palette → Simple Browser: Show\n'
  printf '  2) Open %s  (physical EVO-X3 display)\n' "$URL"
  printf '  3) Optional: http://127.0.0.1:%s/  (ANGELICA UI)\n' "$EVOX3_WEB_PORT"
  printf '\nIf Cursor is local on Gaming-7 (not Remote-SSH):\n'
  printf '  ssh -N -L %s:127.0.0.1:%s -L %s:127.0.0.1:%s evox3\n' \
    "$PORT" "$PORT" "$EVOX3_WEB_PORT" "$EVOX3_WEB_PORT"
  printf '\nStop: ./scripts/evox3/27_remote_screen_preview.sh stop\n'
  ok "27_remote_screen_preview.sh started"
}

case "$ACTION" in
  start|"") cmd_start ;;
  stop) cmd_stop ;;
  status) setup_local_graphical_env; cmd_status ;;
  *) die "Usage: $0 [start|stop|status]" ;;
esac
