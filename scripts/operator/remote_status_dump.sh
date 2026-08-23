#!/usr/bin/env bash
# Paste-friendly ANGELICA stack dump.
# Works from Gaming-7 (SSH to EVO) OR when already on EVO (no nested SSH).
#
#   curl -fsSL https://raw.githubusercontent.com/thomaspas/thoma/cursor/evox3-ip-dhcp-c1c0/scripts/operator/remote_status_dump.sh | bash
#
# Paste the full output into Cursor.
set -euo pipefail
EVOX3_SSH="${EVOX3_SSH:-thomas-pashoulas@192.168.1.9}"
EVOX3_SSH_KEY="${EVOX3_SSH_KEY:-}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)
if [ -n "$EVOX3_SSH_KEY" ] && [ -f "$EVOX3_SSH_KEY" ]; then
  SSH_OPTS+=(-i "$EVOX3_SSH_KEY" -o IdentitiesOnly=yes)
elif [ -f "$HOME/.ssh/id_ed25519_evox3" ]; then
  SSH_OPTS+=(-i "$HOME/.ssh/id_ed25519_evox3" -o IdentitiesOnly=yes)
fi

log() { printf '[*] %s\n' "$*"; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

DUMP_SCRIPT='
set +e
echo "=== ANGELICA STATUS DUMP $(date -Is) ==="
echo "hostname=$(hostname)"
echo "ips=$(hostname -I 2>/dev/null)"
echo "=== thoma ==="
if [ -d "$HOME/thoma/.git" ]; then
  git -C "$HOME/thoma" rev-parse --abbrev-ref HEAD 2>/dev/null
  git -C "$HOME/thoma" rev-parse --short HEAD 2>/dev/null
  git -C "$HOME/thoma" remote get-url origin 2>/dev/null
else
  echo "MISSING ~/thoma"
fi
echo "=== units ==="
for u in evox3-jinhua-docker evox3-bge-m3 evox3-jinhua-api evox3-jinhua-web; do
  printf "%s: %s\n" "$u" "$(systemctl --user is-active "$u.service" 2>/dev/null || echo missing)"
done
echo "=== http/tcp ==="
(echo >/dev/tcp/127.0.0.1/5432) >/dev/null 2>&1 && echo "tcp:5432 OPEN" || echo "tcp:5432 CLOSED"
for url in \
  "http://127.0.0.1:11434/v1/models" \
  "http://127.0.0.1:8002/health" \
  "http://127.0.0.1:8000/docs" \
  "http://127.0.0.1:5173/"
do
  code=$(curl -sS -o /tmp/evox3-status-body -w "%{http_code}" --max-time 3 "$url" 2>/dev/null || echo 000)
  body=$(head -c 160 /tmp/evox3-status-body 2>/dev/null | tr "\n" " ")
  echo "$url -> $code ${body}"
done
echo "=== LLM_MODEL ==="
grep -E "^LLM_MODEL=" "$HOME/ai_apps/IncubativeSecondBrain/.env" 2>/dev/null || echo "(no .env)"
echo "=== recent bge journal ==="
journalctl --user -u evox3-bge-m3.service -n 15 --no-pager 2>/dev/null || echo "(no bge unit)"
echo "=== END STATUS DUMP ==="
'

HOST_NOW="$(hostname -s 2>/dev/null || hostname)"
if printf '%s' "$HOST_NOW" | grep -qi 'EVO-X3'; then
  log "Already on EVO-X3 — dumping locally (no SSH)"
  bash -c "$DUMP_SCRIPT"
  exit 0
fi

command -v ssh >/dev/null || die "ssh missing"
log "Status dump via SSH $EVOX3_SSH (paste this whole block to Cursor)"
if ! ssh "${SSH_OPTS[@]}" "$EVOX3_SSH" "bash -s" <<<"$DUMP_SCRIPT"; then
  log "Retry SSH without BatchMode"
  SSH_OPTS=("${SSH_OPTS[@]/-o BatchMode=yes/}")
  ssh -o ConnectTimeout=15 "${SSH_OPTS[@]}" "$EVOX3_SSH" "bash -s" <<<"$DUMP_SCRIPT" \
    || die "SSH failed — on EVO run: hostname -I ; then EVOX3_SSH=thomas-pashoulas@<ip> $0"
fi
