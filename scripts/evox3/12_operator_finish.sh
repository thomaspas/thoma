#!/usr/bin/env bash
# Operator finish: sync main, skip-auth, smoke, relaunch kiosk, human checklist.
# Run on EVO-X3 (not Cursor Cloud). ASCII only.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

THOMA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SAMPLE_MD="${EVOX3_AI_APPS}/evox3-greek-smoke.md"

# Default git branch: explicit env > land stack (until merged to main) > main.
# Staying on stale origin/main drops scripts 16-20 and causes 10-pass smoke regressions.
resolve_finish_branch() {
  if [ -n "${EVOX3_THOMA_BRANCH:-}" ]; then
    printf '%s\n' "$EVOX3_THOMA_BRANCH"
    return 0
  fi
  if git -C "$THOMA_ROOT" rev-parse --verify refs/remotes/origin/cursor/land-angelica-stack-8dd2 >/dev/null 2>&1; then
    printf '%s\n' "cursor/land-angelica-stack-8dd2"
    return 0
  fi
  printf '%s\n' "main"
}

BRANCH="$(resolve_finish_branch)"

cd "$THOMA_ROOT"

log "=== 12_operator_finish: git sync ($BRANCH) ==="
require_cmd git
if [ -d "$THOMA_ROOT/.git" ]; then
  # Explicit refspec: plain `git fetch origin main` may only update FETCH_HEAD
  # (no refs/remotes/origin/main) on clones that never tracked main.
  git fetch origin "+refs/heads/${BRANCH}:refs/remotes/origin/${BRANCH}"
  if ! git rev-parse --verify "refs/remotes/origin/${BRANCH}" >/dev/null 2>&1; then
    die "Could not fetch origin/${BRANCH} — check network / remote"
  fi
  current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  switched=0
  if [ "$current" != "$BRANCH" ]; then
    log "Checking out $BRANCH (was: ${current:-detached})"
    switched=1
  fi
  git checkout -B "$BRANCH" "origin/${BRANCH}"
  ok "thoma @ $(git rev-parse --short HEAD) on $(git rev-parse --abbrev-ref HEAD)"
  # After switching branches, re-exec so 09/10/11 come from the checked-out tree
  # (avoids running newer 12 then older sibling scripts from previous branch).
  if [ "$switched" = "1" ] && [ "${EVOX3_FINISH_REEXEC:-0}" != "1" ]; then
    log "Re-exec 12_operator_finish.sh from $BRANCH"
    export EVOX3_FINISH_REEXEC=1
    exec bash "$SCRIPT_DIR/12_operator_finish.sh"
  fi
else
  warn "Not a git checkout at $THOMA_ROOT — skip pull"
fi

# Always run 11 (idempotent) so skip-auth patch version upgrades apply.
log "=== 11_skip_auth_ui.sh (idempotent) ==="
bash "$SCRIPT_DIR/11_skip_auth_ui.sh"

log "=== 16_brand_angelica.sh (idempotent) ==="
bash "$SCRIPT_DIR/16_brand_angelica.sh"

log "=== 09_smoke_check.sh ==="
bash "$SCRIPT_DIR/09_smoke_check.sh"

log "=== 10_relaunch_kiosk.sh ==="
bash "$SCRIPT_DIR/10_relaunch_kiosk.sh"

mkdir -p "$(dirname "$SAMPLE_MD")"
cat >"$SAMPLE_MD" <<EOF
# ${EVOX3_BRAND_NAME} Greek smoke note

Το τοπικό ${EVOX3_BRAND_NAME} τρέχει στο EVO-X3 με LOCAL FULL stack.
Ο χρήστης kiosk είναι ${EVOX3_LOCAL_EMAIL}.
Αυτή η σημείωση υπάρχει για δοκιμή ελληνικής συνομιλίας.
EOF
ok "Wrote sample note: $SAMPLE_MD"

printf '\n=== Human checklist (on EVO-X3 desktop) ===\n'
printf '  1) Kiosk shows %s dashboard/chat at http://127.0.0.1:%s (footer: Kiosk · always signed in)\n' \
  "$EVOX3_BRAND_NAME" "$EVOX3_WEB_PORT"
printf '     NOT Register/Login, NOT API JSON on :%s\n' "$EVOX3_API_PORT"
printf '  2) Upload: %s\n' "$SAMPLE_MD"
printf '  3) Ask in Greek chat, e.g.: Ποιος είναι ο kiosk χρήστης στο EVO-X3;\n'
printf '  4) Reboot once, then after desktop login:\n'
printf '       systemctl --user is-active evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service\n'
printf '       %s/scripts/evox3/09_smoke_check.sh\n' "$THOMA_ROOT"
printf '  5) Done — LOCAL FULL operator checklist complete\n'
ok "12_operator_finish.sh complete — do steps 1-4 on screen"
