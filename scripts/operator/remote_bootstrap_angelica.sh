#!/usr/bin/env bash
# From Gaming-7: SSH into EVO-X3 and start LOCAL FULL bootstrap in tmux.
# Survives disconnect better than interactive paste; do not interrupt the remote job.
#
# Usage (on Gaming-7):
#   chmod +x scripts/operator/remote_bootstrap_angelica.sh
#   ./scripts/operator/remote_bootstrap_angelica.sh
#
# Watch:
#   ssh thomas-pashoulas@192.168.1.9 'tail -f ~/ai_apps/angelica-bootstrap.log'
#   ssh thomas-pashoulas@192.168.1.9 'tmux attach -t angelica-bootstrap'
set -euo pipefail

EVOX3_SSH="${EVOX3_SSH:-thomas-pashoulas@192.168.1.9}"
EVOX3_SSH_KEY="${EVOX3_SSH_KEY:-}"
SESSION="${EVOX3_BOOTSTRAP_TMUX:-angelica-bootstrap}"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)
if [ -n "$EVOX3_SSH_KEY" ] && [ -f "$EVOX3_SSH_KEY" ]; then
  SSH_OPTS+=(-i "$EVOX3_SSH_KEY" -o IdentitiesOnly=yes)
elif [ -f "$HOME/.ssh/id_ed25519_evox3" ]; then
  SSH_OPTS+=(-i "$HOME/.ssh/id_ed25519_evox3" -o IdentitiesOnly=yes)
fi

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[+] %s\n' "$*"; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

command -v ssh >/dev/null 2>&1 || die "ssh missing"

log "Probing $EVOX3_SSH ..."
ssh "${SSH_OPTS[@]}" "$EVOX3_SSH" 'hostname; hostname -I | awk "{print \$1}"' \
  || die "SSH failed — check EVO power / Wi-Fi IP (on EVO: hostname -I)"

log "Uploading bootstrap runner + starting tmux:$SESSION"
ssh "${SSH_OPTS[@]}" "$EVOX3_SSH" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p "$HOME/ai_apps" "$HOME/thoma/scripts/operator"
RUNNER="$HOME/ai_apps/angelica-bootstrap-run.sh"
LOG="$HOME/ai_apps/angelica-bootstrap.log"
cat >"$RUNNER" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
export LANG=en_US.UTF-8
LOG="$HOME/ai_apps/angelica-bootstrap.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== angelica bootstrap $(date -Is) ==="
cd "$HOME/thoma"
git remote set-url origin https://github.com/thomaspas/thoma.git || true
git fetch origin || true
chmod +x scripts/evox3/*.sh 2>/dev/null || true
if git rev-parse --verify refs/remotes/origin/cursor/evox3-ip-dhcp-c1c0 >/dev/null 2>&1; then
  git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0 || true
  chmod +x scripts/evox3/*.sh
fi
echo "[*] 02 docker (large pulls — do not interrupt)"
./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh
if [ -x ./scripts/evox3/25_post_reboot_resume.sh ]; then
  echo "[*] 25_post_reboot_resume"
  ./scripts/evox3/25_post_reboot_resume.sh
else
  echo "[*] run_all (creates units)"
  ./scripts/evox3/run_all.sh
  ./scripts/evox3/21_remote_verify.sh
fi
echo "=== bootstrap finished $(date -Is) ==="
EOS
chmod +x "$RUNNER"
if ! command -v tmux >/dev/null 2>&1; then
  echo "[!] tmux missing — trying apt install" >&2
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y tmux
fi
tmux has-session -t angelica-bootstrap 2>/dev/null && tmux kill-session -t angelica-bootstrap || true
tmux new-session -d -s angelica-bootstrap "$RUNNER"
tmux list-sessions
echo "[+] tmux angelica-bootstrap started; log=$LOG"
REMOTE

ok "Bootstrap running on EVO"
printf '\nWatch:\n  ssh %s '\''tail -f ~/ai_apps/angelica-bootstrap.log'\''\n' "$EVOX3_SSH"
printf 'Attach:\n  ssh %s '\''tmux attach -t %s'\''\n' "$EVOX3_SSH" "$SESSION"
printf '\nWhen finished, paste the end of the log (21_remote_verify) to Cursor.\n'
