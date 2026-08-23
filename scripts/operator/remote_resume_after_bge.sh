#!/usr/bin/env bash
# From Gaming-7: SSH to EVO and run 26_resume_after_bge.sh (after 05 health timeout).
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

command -v ssh >/dev/null || die "ssh missing"
log "Running 26_resume_after_bge on $EVOX3_SSH (long — bge load + API/UI)"
ssh "${SSH_OPTS[@]}" "$EVOX3_SSH" 'bash -s' <<'REMOTE'
set -euo pipefail
cd "$HOME/thoma"
git remote set-url origin https://github.com/thomaspas/thoma.git || true
git fetch origin cursor/evox3-ip-dhcp-c1c0
git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0
chmod +x scripts/evox3/*.sh
./scripts/evox3/26_resume_after_bge.sh
REMOTE
log "Done — paste the remote 21_remote_verify section to Cursor"
