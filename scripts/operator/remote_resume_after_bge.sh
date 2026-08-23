#!/usr/bin/env bash
# From Gaming-7: SSH to EVO and run 26_resume_after_bge.sh in tmux (survives disconnect).
#
# Usage:
#   chmod +x scripts/operator/remote_resume_after_bge.sh
#   ./scripts/operator/remote_resume_after_bge.sh
#
# Or one-liner (no local clone):
#   curl -fsSL https://raw.githubusercontent.com/thomaspas/thoma/cursor/evox3-ip-dhcp-c1c0/scripts/operator/remote_resume_after_bge.sh | bash
#
# Watch:
#   ssh thomas-pashoulas@192.168.1.9 'tail -f ~/ai_apps/angelica-resume.log'
set -euo pipefail
EVOX3_SSH="${EVOX3_SSH:-thomas-pashoulas@192.168.1.9}"
EVOX3_SSH_KEY="${EVOX3_SSH_KEY:-}"
SESSION="${EVOX3_RESUME_TMUX:-angelica-resume}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)
if [ -n "$EVOX3_SSH_KEY" ] && [ -f "$EVOX3_SSH_KEY" ]; then
  SSH_OPTS+=(-i "$EVOX3_SSH_KEY" -o IdentitiesOnly=yes)
elif [ -f "$HOME/.ssh/id_ed25519_evox3" ]; then
  SSH_OPTS+=(-i "$HOME/.ssh/id_ed25519_evox3" -o IdentitiesOnly=yes)
fi

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[+] %s\n' "$*"; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

command -v ssh >/dev/null || die "ssh missing"

log "Probing $EVOX3_SSH ..."
ssh "${SSH_OPTS[@]}" "$EVOX3_SSH" 'hostname; hostname -I | awk "{print \$1}"' \
  || die "SSH failed — check EVO power / Wi-Fi IP (on EVO: hostname -I)"

log "Starting tmux:$SESSION on EVO (26_resume — bge load can take a long time)"
ssh "${SSH_OPTS[@]}" "$EVOX3_SSH" 'bash -s' <<'REMOTE'
set -euo pipefail
SESSION="angelica-resume"
mkdir -p "$HOME/ai_apps"
RUNNER="$HOME/ai_apps/angelica-resume-run.sh"
LOG="$HOME/ai_apps/angelica-resume.log"
cat >"$RUNNER" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
export LANG=en_US.UTF-8
LOG="$HOME/ai_apps/angelica-resume.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== angelica resume-after-bge $(date -Is) ==="
cd "$HOME/thoma"
git remote set-url origin https://github.com/thomaspas/thoma.git || true
git fetch origin cursor/evox3-ip-dhcp-c1c0
git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0
chmod +x scripts/evox3/*.sh
./scripts/evox3/26_resume_after_bge.sh
echo "=== resume finished $(date -Is) ==="
EOS
chmod +x "$RUNNER"
if ! command -v tmux >/dev/null 2>&1; then
  echo "[!] tmux missing — trying apt install" >&2
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y tmux
fi
tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION" || true
tmux new-session -d -s "$SESSION" "$RUNNER"
tmux list-sessions
echo "[+] tmux $SESSION started; log=$LOG"
REMOTE

ok "Resume running on EVO (tmux:$SESSION)"
printf '\nWatch:\n  ssh %s '\''tail -f ~/ai_apps/angelica-resume.log'\''\n' "$EVOX3_SSH"
printf 'Attach:\n  ssh %s '\''tmux attach -t %s'\''\n' "$EVOX3_SSH" "$SESSION"
printf '\nWhen you see REMOTE VERIFY OK, paste the end of the log to Cursor.\n'
