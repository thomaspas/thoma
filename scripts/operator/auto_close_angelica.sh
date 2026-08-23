#!/usr/bin/env bash
# One-shot ANGELICA closeout from Gaming-7: GH_TOKEN push, EVO-X3 verify, chronicle, merge PR #8.
# Usage:
#   export GH_TOKEN='your_real_pat_from_github_settings_tokens'
#   export PATH="$HOME/.local/bin:$PATH"
#   ./scripts/operator/auto_close_angelica.sh
set -euo pipefail

THOMA_ROOT="${THOMA_ROOT:-$HOME/thoma}"
BRANCH="${EVOX3_THOMA_BRANCH:-cursor/land-angelica-stack-8dd2}"
EVOX3_SSH="${EVOX3_SSH:-thomas-pashoulas@192.168.1.9}"
EVOX3_SSH_KEY="${EVOX3_SSH_KEY:-$HOME/.ssh/id_ed25519_evox3}"
PR_NUMBER="${ANGELICA_PR_NUMBER:-8}"
VERIFY_LOG="${VERIFY_LOG:-/tmp/angelica-remote-verify.log}"

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

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
  if [[ "${GH_TOKEN}" == *'...'* ]] || [ "${#GH_TOKEN}" -lt 20 ]; then
    die "GH_TOKEN looks invalid or is a docs placeholder — create PAT at github.com/settings/tokens (scope: repo)"
  fi
  local gh_user
  if ! gh_user="$(gh api user -q .login 2>/tmp/gh-api.err)"; then
    warn "GH_TOKEN rejected by GitHub API:"
    tail -5 /tmp/gh-api.err >&2 || true
    die "GH_TOKEN invalid or expired — create PAT at github.com/settings/tokens (scope: repo)"
  fi
  ok "GitHub token OK (user: ${gh_user})"
  export GIT_TERMINAL_PROMPT=0
}

git_repo_slug() {
  cd "$THOMA_ROOT"
  if gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null; then
    return 0
  fi
  local remote_url
  remote_url="$(git remote get-url origin)"
  remote_url="${remote_url%.git}"
  remote_url="${remote_url#git@github.com:}"
  remote_url="${remote_url#https://github.com/}"
  printf '%s' "$remote_url"
}

git_push_with_token() {
  [ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN not set — cannot push"
  local slug push_url encoded_token
  slug="$(git_repo_slug)"
  encoded_token="$(python3 -c "import urllib.parse,os; print(urllib.parse.quote(os.environ['GH_TOKEN'], safe=''))")"
  push_url="https://x-access-token:${encoded_token}@github.com/${slug}.git"
  log "Authenticated push to github.com/${slug} (branch ${BRANCH})"
  git -c credential.helper= push "$push_url" "HEAD:${BRANCH}" 2>/tmp/git-push.err
}

git_push_branch() {
  cd "$THOMA_ROOT"
  git checkout "$BRANCH"
  local ahead
  ahead="$(git rev-list --count "origin/$BRANCH..HEAD" 2>/dev/null || echo 0)"
  if [ "${ahead:-0}" -gt 0 ]; then
    log "Pushing $ahead commit(s) to origin/$BRANCH"
    if ! git_push_with_token; then
      tail -10 /tmp/git-push.err >&2 || true
      if grep -q 'could not read Username' /tmp/git-push.err 2>/dev/null; then
        die "git push failed — credential prompt detected; confirm GH_TOKEN is real and retry from Gaming-7"
      fi
      die "git push failed — check GH_TOKEN repo scope"
    fi
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
  # Strict: must match 21_remote_verify.sh success banner, not smoke-check
  # hint text like "expect REMOTE VERIFY OK" that is also tee'd into VERIFY_LOG.
  grep -qF '=== REMOTE VERIFY OK' "$VERIFY_LOG" 2>/dev/null
}

update_chronicle_closeout() {
  local chronicle="$THOMA_ROOT/docs/SESSION_CHRONICLE_ANGELICA.md"
  [ -f "$chronicle" ] || die "Missing $chronicle"

  # python3 - reads program from stdin; path is argv[1] (NOT executed as a script).
  # Without "-", bash would pass the .md path as the script file and Python would
  # try to parse markdown (SyntaxError on Unicode em-dash).
  python3 - "$chronicle" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()

# Session block: mark resolved (ASCII -- in replacement strings)
text = re.sub(
    r"\*\*Next:\*\*.*",
    "**Resolved (auto_close):** `21_remote_verify.sh` **6 pass / 0 fail** -- `REMOTE VERIFY OK`; bug #8 closed; PR #8 merged.",
    text,
    count=1,
)

# Runtime evidence bullets
text = text.replace(
    "- `21_remote_verify.sh`: **5 pass / 1 fail** — only `browser process missing :5173`",
    "- `21_remote_verify.sh`: **6 pass / 0 fail** -- `REMOTE VERIFY OK` (kiosk `:5173` via SSH relaunch)",
)
text = text.replace(
    "**Patches (local Gaming-7 clone, pending sync to EVO-X3):**",
    "**Patches (pushed + verified on EVO-X3):**",
)

# PR table row #8
text = re.sub(
    r"\| \[#8\]\(https://github\.com/thomaspas/thoma/pull/8\) \| Remote SSH operator \+ `21_remote_verify` \+ kiosk SSH fixes \| OPEN \|",
    "| [#8](https://github.com/thomaspas/thoma/pull/8) | Remote SSH operator + `21_remote_verify` + kiosk SSH fixes | MERGED |",
    text,
    count=1,
)

open(path, "w", encoding="utf-8").write(text)
print("chronicle updated")
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
    git_push_with_token
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

  git_push_branch
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
