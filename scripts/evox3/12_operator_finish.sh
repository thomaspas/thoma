#!/usr/bin/env bash
# Operator finish: sync PR branch, skip-auth, smoke, relaunch kiosk, human checklist.
# Run on EVO-X3 (not Cursor Cloud). ASCII only.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

THOMA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BRANCH="cursor/jinhua-local-full-evox3-02ac"
SAMPLE_MD="${EVOX3_AI_APPS}/evox3-greek-smoke.md"

cd "$THOMA_ROOT"

log "=== 12_operator_finish: git sync ($BRANCH) ==="
require_cmd git
if [ -d "$THOMA_ROOT/.git" ]; then
  git fetch origin "$BRANCH"
  current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  if [ "$current" != "$BRANCH" ]; then
    log "Checking out $BRANCH (was: ${current:-detached})"
    git checkout "$BRANCH"
  fi
  git pull --ff-only origin "$BRANCH"
  ok "thoma @ $(git rev-parse --short HEAD) on $BRANCH"
else
  warn "Not a git checkout at $THOMA_ROOT — skip pull"
fi

# Always run 11 (idempotent) so skip-auth patch version upgrades apply.
log "=== 11_skip_auth_ui.sh (idempotent) ==="
bash "$SCRIPT_DIR/11_skip_auth_ui.sh"

log "=== 09_smoke_check.sh ==="
bash "$SCRIPT_DIR/09_smoke_check.sh"

log "=== 10_relaunch_kiosk.sh ==="
bash "$SCRIPT_DIR/10_relaunch_kiosk.sh"

mkdir -p "$(dirname "$SAMPLE_MD")"
cat >"$SAMPLE_MD" <<'EOF'
# EVO-X3 Greek smoke note

Το τοπικό Second Brain τρέχει στο EVO-X3 με LOCAL FULL stack.
Ο χρήστης kiosk είναι ye@evox3.local.
Αυτή η σημείωση υπάρχει για δοκιμή ελληνικής συνομιλίας.
EOF
ok "Wrote sample note: $SAMPLE_MD"

printf '\n=== Human checklist (on EVO-X3 desktop) ===\n'
printf '  1) Kiosk shows dashboard/chat at http://127.0.0.1:%s (footer: Kiosk · always signed in)\n' \
  "$EVOX3_WEB_PORT"
printf '     NOT Register/Login, NOT API JSON on :%s\n' "$EVOX3_API_PORT"
printf '  2) Upload: %s\n' "$SAMPLE_MD"
printf '  3) Ask in Greek chat, e.g.: Ποιος είναι ο kiosk χρήστης στο EVO-X3;\n'
printf '  4) Reboot once, then after desktop login:\n'
printf '       systemctl --user is-active evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service\n'
printf '       %s/scripts/evox3/09_smoke_check.sh\n' "$THOMA_ROOT"
printf '  5) When 1-4 pass: merge PR #1 (already ready for review)\n'
ok "12_operator_finish.sh complete — do steps 1-4 on screen, then merge"
