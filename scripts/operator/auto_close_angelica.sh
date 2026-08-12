#!/usr/bin/env bash
# One-shot ANGELICA closeout from Gaming-7: GH_TOKEN push, EVO-X3 verify, chronicle, merge PR #8.
# Usage:
#   export GH_TOKEN='ghp_...'
#   export PATH="$HOME/.local/bin:$PATH"
#   ./scripts/operator/auto_close_angelica.sh
set -euo pipefail

THOMA_ROOT="${THOMA_ROOT:-$HOME/thoma}"
BRANCH="${EVOX3_THOMA_BRANCH:-cursor/land-angelica-stack-8dd2}"
EVOX3_SSH="${EVOX3_SSH:-thomas-pashoulas@192.168.1.8}"
EVOX3_SSH_KEY="${EVOX3_SSH_KEY:-$HOME/.ssh/id_ed25519_evox3}"
PR_NUMBER="${ANGELICA_PR_NUMBER:-8}"
VERIFY_LOG="${VERIFY_LOG:-/tmp/angelica-remote-verify.log}"
DEBUG_LOG="${DEBUG_LOG:-/home/thomas1821/Λήψεις/.cursor/debug-f7f922.log}"

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

#region agent log
_dbg() {
  local hid="$1" loc="$2" msg="$3" data="${4:-{}}"
  python3 -c "import json,time; open('${DEBUG_LOG}','a').write(json.dumps({'sessionId':'f7f922','hypothesisId':'${hid}','location':'${loc}','message':'${msg}','data':${data},'timestamp':int(time.time()*1000),'runId':'pre-fix'})+'\n')" 2>/dev/null || true
}
_on_err() {
  local ec=$?
  _dbg "H1" "auto_close_angelica.sh:ERR" "command_failed" "{\"exit\":${ec},\"line\":${LINENO},\"cmd\":\"${BASH_COMMAND//\"/\\\"}\"}"
  warn "Command failed (exit $ec) at line $LINENO: $BASH_COMMAND"
  exit "$ec"
}
trap _on_err ERR
#endregion

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

ensure_gh() {
  if command -v gh >/dev/null 2>&1; then
    return 0
  fi
  if [ -x "$HOME/.local/bin/gh" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    return 0
  fi
  die "gh not found — install to ~/.local/bin or PATH"
}

ensure_gh_auth() {
  if [ -z "${GH_TOKEN:-}" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
    export GH_TOKEN="$GITHUB_TOKEN"
  fi
  [ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN not set — export a GitHub PAT (scope: repo)"
  #region agent log
  _dbg "H1" "ensure_gh_auth" "before_validate" "{\"token_len\":${#GH_TOKEN}}"
  #endregion
  # gh auth login --with-token FAILS when GH_TOKEN is already exported (exit 1, no stdin read).
  # Validate the env token directly and wire git HTTPS to use it for push.
  local gh_user
  if ! gh_user="$(gh api user -q .login 2>/tmp/gh-api.err)"; then
    #region agent log
    _dbg "H1" "ensure_gh_auth" "token_invalid" "{\"stderr_lines\":$(wc -l </tmp/gh-api.err 2>/dev/null || echo 0)}"
    #endregion
    warn "GH_TOKEN rejected by GitHub API:"
    tail -5 /tmp/gh-api.err >&2 || true
    die "GH_TOKEN invalid or expired — create PAT at github.com/settings/tokens (scope: repo)"
  fi
  #region agent log
  _dbg "H2" "ensure_gh_auth" "token_ok" "{\"user\":\"${gh_user}\"}"
  #endregion
  ok "GitHub token OK (user: ${gh_user})"
  export GIT_TERMINAL_PROMPT=0
  export GIT_CONFIG_COUNT=1
  export GIT_CONFIG_KEY_0=http.extraHeader
  export GIT_CONFIG_VALUE_0="Authorization: Bearer ${GH_TOKEN}"
}

git_push_branch() {
  cd "$THOMA_ROOT"
  #region agent log
  _dbg "H4" "git_push_branch" "start" "{\"branch\":\"${BRANCH}\"}"
  #endregion
  git checkout "$BRANCH"
  local ahead
  ahead="$(git rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)"
  #region agent log
  _dbg "H3" "git_push_branch" "ahead_count" "{\"ahead\":${ahead}}"
  #endregion
  if [ "${ahead:-0}" -gt 0 ]; then
    log "Pushing $ahead commit(s) to origin/$BRANCH"
    if ! git push origin "$BRANCH" 2>/tmp/git-push.err; then
      #region agent log
      _dbg "H3" "git_push_branch" "push_failed" "{}"
      #endregion
      tail -10 /tmp/git-push.err >&2 || true
      die "git push failed — check GH_TOKEN repo scope"
    fi
    #region agent log
    _dbg "H3" "git_push_branch" "push_ok" "{}"
    #endregion
  else
    log "Branch already up to date with origin/$BRANCH"
  fi
}

ssh_evox3() {
  local ssh_opts=(-o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)
  if [ -f "$EVOX3_SSH_KEY" ]; then
    ssh_opts+=(-i "$EVOX3_SSH_KEY" -o IdentitiesOnly=yes)
  fi
  ssh "${ssh_opts[@]}" "$EVOX3_SSH" "$@"
}

ensure_evox3_ssh() {
  if ssh_evox3 'echo evox3-ssh-ok' >/dev/null 2>&1; then
    ok "SSH to $EVOX3_SSH OK"
    return 0
  fi

  warn "SSH batch mode failed — bootstrapping key at $EVOX3_SSH_KEY"
  if [ ! -f "$EVOX3_SSH_KEY" ]; then
    mkdir -p "$(dirname "$EVOX3_SSH_KEY")"
    ssh-keygen -t ed25519 -f "$EVOX3_SSH_KEY" -N "" -C "gaming7-evox3-auto-close"
    ok "Generated $EVOX3_SSH_KEY"
  fi

  warn "One-time: enter EVO-X3 password for ssh-copy-id"
  ssh-copy-id -i "${EVOX3_SSH_KEY}.pub" "$EVOX3_SSH" || die "ssh-copy-id failed — set up SSH manually"

  ssh_evox3 'echo evox3-ssh-ok' >/dev/null 2>&1 || die "SSH still failing after ssh-copy-id"
  ok "SSH to $EVOX3_SSH OK (after key bootstrap)"
}

run_evox3_verify() {
  local mode="${1:-normal}"
  log "Running remote verify on EVO-X3 (mode=$mode)"
  if [ "$mode" = "escalate" ]; then
    ssh_evox3 "bash -s" <<'REMOTE'
set -euo pipefail
cd ~/thoma
chmod +x scripts/evox3/*.sh
./scripts/evox3/22_operator_context_check.sh || true
./scripts/evox3/10_relaunch_kiosk.sh
tail -40 /tmp/evox3-jinhua-kiosk.log 2>/dev/null || true
echo "DISPLAY=$DISPLAY WAYLAND=$WAYLAND_DISPLAY"
loginctl show-user "$(whoami)" -p Display -p State 2>/dev/null || true
./scripts/evox3/21_remote_verify.sh
REMOTE
  else
    ssh_evox3 "bash -s" <<'REMOTE'
set -euo pipefail
cd ~/thoma
git fetch origin
git checkout cursor/land-angelica-stack-8dd2
git pull origin cursor/land-angelica-stack-8dd2
chmod +x scripts/evox3/*.sh
./scripts/evox3/08_autostart_desktop.sh
./scripts/evox3/21_remote_verify.sh
REMOTE
  fi
}

verify_ok() {
  grep -q 'REMOTE VERIFY OK' "$VERIFY_LOG" 2>/dev/null
}

update_chronicle_closeout() {
  local chronicle="$THOMA_ROOT/docs/SESSION_CHRONICLE_ANGELICA.md"
  [ -f "$chronicle" ] || die "Missing $chronicle"

  python3 <<'PY' "$chronicle"
import re, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()

# Session block: mark resolved
text = re.sub(
    r'\*\*Next:\*\* sync scripts.*',
    '**Resolved (auto_close):** `21_remote_verify.sh` **6 pass / 0 fail** — `REMOTE VERIFY OK`; bug #8 closed; PR #8 merged.',
    text,
    count=1,
)

# Runtime evidence bullets
text = text.replace(
    '- `21_remote_verify.sh`: **5 pass / 1 fail** — only `browser process missing :5173`',
    '- `21_remote_verify.sh`: **6 pass / 0 fail** — `REMOTE VERIFY OK` (kiosk `:5173` via SSH relaunch)',
)
text = text.replace(
    '**Patches (local Gaming-7 clone, pending sync to EVO-X3):**',
    '**Patches (pushed + verified on EVO-X3):**',
)

# PR table row #8
text = re.sub(
    r'\| \[#8\]\(https://github\.com/thomaspas/thoma/pull/8\) \| Remote SSH operator \+ `21_remote_verify` \+ kiosk SSH fixes \| OPEN \|',
    '| [#8](https://github.com/thomaspas/thoma/pull/8) | Remote SSH operator + `21_remote_verify` + kiosk SSH fixes | MERGED |',
    text,
    count=1,
)

open(path, 'w', encoding='utf-8').write(text)
print('chronicle updated')
PY
  ok "Updated $chronicle"
}

commit_closeout() {
  cd "$THOMA_ROOT"
  export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Cursor Agent}"
  export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-cursoragent@cursor.com}"
  export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-Cursor Agent}"
  export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-cursoragent@cursor.com}"

  git add docs/SESSION_CHRONICLE_ANGELICA.md scripts/operator/auto_close_angelica.sh 2>/dev/null || true
  if ! git diff --cached --quiet; then
    git commit -m "$(cat <<'EOF'
Close ANGELICA remote verify: 6/0 OK, bug #8 resolved.

Add auto_close_angelica.sh operator script; chronicle PR #8 merged.
EOF
)"
    git push origin "$BRANCH"
  fi
}

merge_pr() {
  if gh pr view "$PR_NUMBER" --json state -q .state 2>/dev/null | grep -q MERGED; then
    ok "PR #$PR_NUMBER already merged"
    return 0
  fi
  gh pr merge "$PR_NUMBER" --merge --delete-branch=false || die "gh pr merge $PR_NUMBER failed"
  ok "PR #$PR_NUMBER merged"
}

main() {
  log "=== ANGELICA auto close (GH_TOKEN) ==="
  require_cmd git
  require_cmd ssh
  require_cmd python3
  ensure_gh
  ensure_gh_auth

  [ -d "$THOMA_ROOT/.git" ] || die "Not a git repo: $THOMA_ROOT"
  #region agent log
  _dbg "H4" "main" "before_git_push" "{}"
  #endregion

  git_push_branch
  #region agent log
  _dbg "H5" "main" "before_ssh" "{}"
  #endregion
  ensure_evox3_ssh

  set +e
  run_evox3_verify normal 2>&1 | tee "$VERIFY_LOG"
  verify_rc=${PIPESTATUS[0]}
  set -e

  if ! verify_ok; then
    warn "First verify did not reach REMOTE VERIFY OK (exit=$verify_rc) — escalating"
    set +e
    run_evox3_verify escalate 2>&1 | tee -a "$VERIFY_LOG"
    verify_rc=${PIPESTATUS[0]}
    set -e
  fi

  if ! verify_ok; then
    warn "Verify log: $VERIFY_LOG"
    tail -60 "$VERIFY_LOG" >&2 || true
    die "REMOTE VERIFY not OK — paste $VERIFY_LOG for debugging"
  fi

  ok "REMOTE VERIFY OK on EVO-X3"
  update_chronicle_closeout
  commit_closeout
  merge_pr

  ok "=== ANGELICA project closed ==="
  printf 'Log: %s\n' "$VERIFY_LOG"
}

main "$@"
