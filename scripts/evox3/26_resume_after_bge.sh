#!/usr/bin/env bash
# Resume LOCAL FULL after 05 bge-m3 health timeout (Docker already up).
# Run on EVO-X3. ASCII only.
#
# Also safe when API/web units were never installed (run_all died in 05).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

HOST_NOW="$(hostname -s 2>/dev/null || hostname)"
if ! printf '%s' "$HOST_NOW" | grep -qi 'EVO-X3'; then
  die "Run on EVO-X3 only (hostname=${HOST_NOW})"
fi

log "=== 26_resume_after_bge: preflight docker / .env / venv ==="
if [ ! -d "$EVOX3_JINHUA_DIR" ]; then
  die "Missing $EVOX3_JINHUA_DIR — run ./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh first"
fi

if ! wait_for_tcp 127.0.0.1 5432 5; then
  warn "Postgres :5432 closed — ensuring docker compose"
  bash "$SCRIPT_DIR/02_ensure_jinhua_clone_and_docker.sh"
  wait_for_tcp 127.0.0.1 5432 120 || die "Postgres :5432 still closed after 02"
fi
ok "Postgres :5432 open"

if [ ! -f "$EVOX3_JINHUA_DIR/.env" ]; then
  warn "Missing .env — running 03"
  bash "$SCRIPT_DIR/03_write_local_env.sh"
fi
if [ ! -x "$EVOX3_JINHUA_DIR/.venv/bin/python" ]; then
  warn "Missing venv — running 04"
  bash "$SCRIPT_DIR/04_install_python_deps.sh"
fi

log "=== 26_resume_after_bge: bge-m3 ==="
ensure_dir "$EVOX3_BGE_DIR"

bge_health_ok() {
  local code
  code="$(curl -sS -o /tmp/evox3-bge-health.json -w '%{http_code}' --max-time 3 "http://127.0.0.1:${EVOX3_BGE_PORT}/health" 2>/dev/null || echo 000)"
  [ "$code" = "200" ] && grep -q '"status"[[:space:]]*:[[:space:]]*"ok"' /tmp/evox3-bge-health.json 2>/dev/null
}

bge_still_loading() {
  local code
  code="$(curl -sS -o /tmp/evox3-bge-health.json -w '%{http_code}' --max-time 3 "http://127.0.0.1:${EVOX3_BGE_PORT}/health" 2>/dev/null || echo 000)"
  [ "$code" = "503" ] && grep -qi 'model_loading' /tmp/evox3-bge-health.json 2>/dev/null
}

# If model already finished after a prior 05 timeout, do not restart (avoids 20+ min reload).
if bge_health_ok; then
  ok "bge-m3 already healthy — skip restart"
else
  NEED_RESTART=1
  if [ "${EVOX3_BGE_FORCE_RESTART:-0}" != "1" ] && bge_still_loading; then
    NEED_RESTART=0
    log "bge-m3 still loading model — wait without restart"
  fi
  if [ "$NEED_RESTART" = "1" ]; then
    if [ -f "$SCRIPT_DIR/bge_m3_server.py" ]; then
      cp -f "$SCRIPT_DIR/bge_m3_server.py" "$EVOX3_BGE_DIR/bge_m3_server.py"
      chmod +x "$EVOX3_BGE_DIR/bge_m3_server.py"
    fi
    if systemctl --user cat evox3-bge-m3.service >/dev/null 2>&1; then
      log "install fixed bge server + restart unit"
      systemctl --user restart evox3-bge-m3.service || warn "restart bge failed"
    else
      bash "$SCRIPT_DIR/05_start_bge_m3_server.sh"
    fi
  fi

  WAIT_LOOPS="${EVOX3_BGE_HEALTH_LOOPS:-600}"
  WAIT_SLEEP="${EVOX3_BGE_HEALTH_SLEEP:-3}"
  log "Waiting for bge-m3 /health ok (up to $((WAIT_LOOPS * WAIT_SLEEP))s)"
  READY=0
  for i in $(seq 1 "$WAIT_LOOPS"); do
    if bge_health_ok; then
      READY=1
      break
    fi
    if [ $((i % 20)) -eq 0 ]; then
      code="$(curl -sS -o /tmp/evox3-bge-health.json -w '%{http_code}' --max-time 3 "http://127.0.0.1:${EVOX3_BGE_PORT}/health" 2>/dev/null || echo 000)"
      detail="$(head -c 120 /tmp/evox3-bge-health.json 2>/dev/null || true)"
      log "still waiting (http=${code}, ${i}/${WAIT_LOOPS}) ${detail}"
    fi
    sleep "$WAIT_SLEEP"
  done
  [ "$READY" = "1" ] || die "bge-m3 still unhealthy — journalctl --user -u evox3-bge-m3 -n 50"
  ok "bge-m3 healthy"
fi

log "=== align LLM_MODEL to live llama ==="
ID="$(curl -fsS --max-time 5 "${EVOX3_LLM_BASE_URL}/models" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0]["id"])')"
[ -n "$ID" ] || die "could not read live LLM model id from ${EVOX3_LLM_BASE_URL}/models"
ENV_PATH="$EVOX3_JINHUA_DIR/.env"
[ -f "$ENV_PATH" ] || die "missing $ENV_PATH — run 03 first"
if grep -q '^LLM_MODEL=' "$ENV_PATH"; then
  sed -i "s|^LLM_MODEL=.*|LLM_MODEL=${ID}|" "$ENV_PATH"
else
  printf 'LLM_MODEL=%s\n' "$ID" >>"$ENV_PATH"
fi
ok "LLM_MODEL=${ID}"

for step in \
  06_migrate_and_start_api.sh \
  07_start_frontend_and_kiosk.sh \
  08_autostart_desktop.sh \
  11_skip_auth_ui.sh \
  16_brand_angelica.sh \
  10_relaunch_kiosk.sh \
  21_remote_verify.sh
do
  log "=== $step ==="
  bash "$SCRIPT_DIR/$step"
done

ok "26_resume_after_bge.sh finished — paste 21 output if not REMOTE VERIFY OK"
