#!/usr/bin/env bash
# Auto-seed fixed local user and patch web UI to skip AuthScreen (no register/login).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd curl
require_cmd python3
require_cmd systemctl

WEB_SRC="$EVOX3_JINHUA_DIR/apps/web/src"
APP_TSX="$WEB_SRC/App.tsx"
APP_BAK="$WEB_SRC/App.tsx.evox3-orig"
AUTO_TS="$WEB_SRC/evox3AutoAuth.ts"
MARKER="$EVOX3_JINHUA_DIR/apps/web/.evox3-skip-auth"
API_BASE="http://${EVOX3_API_HOST}:${EVOX3_API_PORT}"
# Bump when App.tsx patch shape changes so re-runs refresh an older patch.
EVOX3_SKIP_AUTH_VERSION="2"

[ -d "$EVOX3_JINHUA_DIR" ] || die "Missing $EVOX3_JINHUA_DIR — run 02 first"
[ -f "$APP_TSX" ] || die "Missing $APP_TSX — is the Jinhua web app present?"

# Login/register need Postgres. After reboot, compose may still be down.
if ! wait_for_tcp 127.0.0.1 5432 2; then
  warn "Postgres :5432 closed — starting docker compose via 02"
  bash "$SCRIPT_DIR/02_ensure_jinhua_clone_and_docker.sh"
fi
if ! wait_for_tcp 127.0.0.1 5432 30; then
  die "Postgres still down on :5432 — fix Docker first (docker compose ps)"
fi

CRED_FINGERPRINT="$(printf '%s|%s|%s|%s' "$EVOX3_SKIP_AUTH_VERSION" "$EVOX3_LOCAL_EMAIL" "$EVOX3_LOCAL_PASSWORD" "$EVOX3_LOCAL_DISPLAY_NAME" | sha256sum | awk '{print $1}')"

# ---------------------------------------------------------------------------
# A. Ensure API is up, then register-or-login fixed local account
# ---------------------------------------------------------------------------
log "Waiting for API at ${API_BASE}/docs"
READY=0
for _ in $(seq 1 60); do
  if curl -fsS "${API_BASE}/docs" >/dev/null 2>&1 \
    || curl -fsS "${API_BASE}/openapi.json" >/dev/null 2>&1 \
    || curl -fsS "${API_BASE}/health" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
[ "$READY" -eq 1 ] || die "API not ready on ${API_BASE}"

seed_or_login() {
  local reg_code login_code body
  body="$(python3 - <<PY
import json
print(json.dumps({
    "email": """${EVOX3_LOCAL_EMAIL}""",
    "password": """${EVOX3_LOCAL_PASSWORD}""",
    "display_name": """${EVOX3_LOCAL_DISPLAY_NAME}""",
}))
PY
)"

  reg_code="$(curl -sS -o /tmp/evox3-auth-register.json -w '%{http_code}' \
    -X POST "${API_BASE}/auth/register" \
    -H 'Content-Type: application/json' \
    -d "$body" || true)"

  if [ "$reg_code" = "201" ] || [ "$reg_code" = "200" ]; then
    ok "Registered local account ${EVOX3_LOCAL_EMAIL}"
    return 0
  fi

  if [ "$reg_code" = "409" ]; then
    log "Account exists — trying login"
  else
    warn "Register returned HTTP ${reg_code}; trying login"
    cat /tmp/evox3-auth-register.json 2>/dev/null || true
  fi

  login_body="$(python3 - <<PY
import json
print(json.dumps({
    "email": """${EVOX3_LOCAL_EMAIL}""",
    "password": """${EVOX3_LOCAL_PASSWORD}""",
}))
PY
)"
  login_code="$(curl -sS -o /tmp/evox3-auth-login.json -w '%{http_code}' \
    -X POST "${API_BASE}/auth/login" \
    -H 'Content-Type: application/json' \
    -d "$login_body" || true)"

  if [ "$login_code" = "200" ]; then
    ok "Logged in as ${EVOX3_LOCAL_EMAIL}"
    return 0
  fi

  warn "Login failed (HTTP ${login_code}) — resetting password for ${EVOX3_LOCAL_EMAIL}"
  cat /tmp/evox3-auth-login.json 2>/dev/null || true

  [ -x "$EVOX3_JINHUA_DIR/.venv/bin/python" ] || die "Missing venv — cannot reset password"

  (
    cd "$EVOX3_JINHUA_DIR"
    EVOX3_LOCAL_EMAIL="$EVOX3_LOCAL_EMAIL" \
    EVOX3_LOCAL_PASSWORD="$EVOX3_LOCAL_PASSWORD" \
    EVOX3_LOCAL_DISPLAY_NAME="$EVOX3_LOCAL_DISPLAY_NAME" \
    .venv/bin/python - <<'PY'
import os
from secondbrain.core.auth import hash_password
from secondbrain.db.repositories import users as users_repo
from secondbrain.db.session import session_scope

email = os.environ["EVOX3_LOCAL_EMAIL"].lower().strip()
password = os.environ["EVOX3_LOCAL_PASSWORD"]
display = os.environ["EVOX3_LOCAL_DISPLAY_NAME"]

with session_scope() as session:
    user = users_repo.get_by_email(session, email)
    if user is None:
        users_repo.create_with_workspace(
            session,
            email=email,
            display_name=display,
            password_hash=hash_password(password),
        )
        print("CREATED")
    else:
        user.password_hash = hash_password(password)
        if display:
            user.display_name = display
        session.add(user)
        print("PASSWORD_RESET")
PY
  )

  login_code="$(curl -sS -o /tmp/evox3-auth-login.json -w '%{http_code}' \
    -X POST "${API_BASE}/auth/login" \
    -H 'Content-Type: application/json' \
    -d "$login_body" || true)"
  [ "$login_code" = "200" ] || die "Login still failing after password reset (HTTP ${login_code})"
  ok "Password reset + login OK for ${EVOX3_LOCAL_EMAIL}"
}

seed_or_login

# ---------------------------------------------------------------------------
# B. Patch frontend (idempotent)
# ---------------------------------------------------------------------------
NEED_PATCH=0
if [ -f "$MARKER" ] && [ -f "$AUTO_TS" ] && grep -q 'EVOX3_SKIP_AUTH' "$APP_TSX" 2>/dev/null; then
  OLD_FP="$(tr -d '[:space:]' < "$MARKER" || true)"
  if [ "$OLD_FP" = "$CRED_FINGERPRINT" ]; then
    ok "Skip-auth patch already applied with same credentials"
  else
    log "Skip-auth patch outdated or credentials changed — refreshing"
    NEED_PATCH=1
  fi
else
  NEED_PATCH=1
fi

# Force refresh if Sign out button still present (pre-v2 patch).
if grep -q 'onClick={signOut}>Sign out</button>' "$APP_TSX" 2>/dev/null; then
  log "Sign out button still present — forcing skip-auth v2 refresh"
  NEED_PATCH=1
fi

if [ "${NEED_PATCH:-0}" = "1" ]; then
  if [ ! -f "$APP_BAK" ]; then
    cp "$APP_TSX" "$APP_BAK"
    ok "Backed up App.tsx -> App.tsx.evox3-orig"
  fi

  # Escape for TS string literals
  EMAIL_JS="$(E="$EVOX3_LOCAL_EMAIL" python3 -c 'import json,os; print(json.dumps(os.environ["E"]))')"
  PASS_JS="$(P="$EVOX3_LOCAL_PASSWORD" python3 -c 'import json,os; print(json.dumps(os.environ["P"]))')"
  NAME_JS="$(N="$EVOX3_LOCAL_DISPLAY_NAME" python3 -c 'import json,os; print(json.dumps(os.environ["N"]))')"

  cat > "$AUTO_TS" <<EOF
// EVOX3_SKIP_AUTH — generated by scripts/evox3/11_skip_auth_ui.sh (do not edit by hand)
import { api, type AuthSession } from "./lib/api";

export const EVOX3_LOCAL_EMAIL = ${EMAIL_JS};
export const EVOX3_LOCAL_PASSWORD = ${PASS_JS};
export const EVOX3_LOCAL_DISPLAY_NAME = ${NAME_JS};

/** Login (or register once) as the fixed local kiosk account. */
export async function ensureEvox3Session(): Promise<AuthSession> {
  try {
    return await api.login(EVOX3_LOCAL_EMAIL, EVOX3_LOCAL_PASSWORD);
  } catch (err) {
    try {
      return await api.register(EVOX3_LOCAL_EMAIL, EVOX3_LOCAL_PASSWORD, EVOX3_LOCAL_DISPLAY_NAME);
    } catch {
      throw err;
    }
  }
}
EOF
  ok "Wrote $AUTO_TS"

  python3 - "$APP_TSX" "$APP_BAK" <<'PY'
from pathlib import Path
import re
import sys

app_path = Path(sys.argv[1])
bak_path = Path(sys.argv[2])
text = bak_path.read_text() if bak_path.exists() else app_path.read_text()

# Always patch from pristine backup when available so re-runs stay clean.
if bak_path.exists():
    text = bak_path.read_text()

# 1) Swap AuthScreen import for auto-auth helper
text2, n = re.subn(
    r'import AuthScreen from ["\']\./components/AuthScreen["\'];\s*',
    'import { ensureEvox3Session } from "./evox3AutoAuth"; // EVOX3_SKIP_AUTH\n',
    text,
    count=1,
)
if n != 1:
    raise SystemExit("Could not replace AuthScreen import in App.tsx")
text = text2

# 2) Inject boot effect before authenticate()
auth_fn = re.search(
    r'function authenticate\(next: AuthSession\) \{\s*'
    r'setAccessToken\(next\.access_token\);\s*'
    r'localStorage\.setItem\("sb:session", JSON\.stringify\(next\)\);\s*'
    r'setSession\(next\);\s*'
    r'\}',
    text,
)
if not auth_fn:
    raise SystemExit("Could not locate authenticate() in App.tsx")

inject = '''
  // EVOX3_SKIP_AUTH_BEGIN
  const [authBoot, setAuthBoot] = useState(true);
  const [authError, setAuthError] = useState("");

  useEffect(() => {
    if (session) {
      setAuthBoot(false);
      return;
    }
    let cancelled = false;
    (async () => {
      setAuthBoot(true);
      setAuthError("");
      try {
        const next = await ensureEvox3Session();
        if (!cancelled) {
          setAccessToken(next.access_token);
          localStorage.setItem("sb:session", JSON.stringify(next));
          setSession(next);
        }
      } catch (err) {
        if (!cancelled) {
          setAuthError(err instanceof Error ? err.message : "Auto-login failed");
        }
      } finally {
        if (!cancelled) setAuthBoot(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [session]);
  // EVOX3_SKIP_AUTH_END
'''

insert_at = auth_fn.start()
text = text[:insert_at] + inject + "\n  " + text[insert_at:]

# Kiosk: Sign out is a no-op (stays signed in as fixed local account).
text2, n = re.subn(
    r'function signOut\(\) \{\s*'
    r'setAccessToken\(null\);\s*'
    r'localStorage\.removeItem\("sb:session"\);\s*'
    r'setSession\(null\);\s*'
    r'\}',
    'function signOut() {\n'
    '    // EVOX3_SKIP_AUTH: kiosk stays signed in — ignore Sign out\n'
    '    return;\n'
    '  }',
    text,
    count=1,
)
if n != 1:
    raise SystemExit("Could not patch signOut() in App.tsx")
text = text2

# Hide Sign out button (avoid confusing logout flash / errors on kiosk).
text2, n = re.subn(
    r'<button type="button" className="btn ghost sm" onClick=\{signOut\}>Sign out</button>',
    '<span className="muted sm" title="EVOX3_SKIP_AUTH">Kiosk · always signed in</span>',
    text,
    count=1,
)
if n != 1:
    raise SystemExit("Could not replace Sign out button in App.tsx")
text = text2

# Replace AuthScreen gate
text2, n = re.subn(
    r'if\s*\(\s*!session\s*\)\s*\{?\s*'
    r'return\s*\(?\s*<AuthScreen\s+onAuthenticated=\{authenticate\}\s*/>\s*\)?\s*;?\s*'
    r'\}?',
    'if (!session) {\n'
    '    // EVOX3_SKIP_AUTH: never render AuthScreen\n'
    '    if (authError) {\n'
    '      return (\n'
    '        <div style={{ padding: 32, fontFamily: "sans-serif" }}>\n'
    '          <p>Auto-login failed: {authError}</p>\n'
    '          <p>Re-run scripts/evox3/11_skip_auth_ui.sh on EVO-X3.</p>\n'
    '        </div>\n'
    '      );\n'
    '    }\n'
    '    return (\n'
    '      <div style={{ padding: 32, fontFamily: "sans-serif" }}>\n'
    '        {authBoot ? "Connecting…" : "Starting workspace…"}\n'
    '      </div>\n'
    '    );\n'
    '  }',
    text,
    count=1,
)
if n != 1:
    raise SystemExit(
        "Could not replace AuthScreen gate in App.tsx — check upstream AuthScreen usage"
    )
text = text2

if "ensureEvox3Session" not in text:
    raise SystemExit("Patch incomplete: ensureEvox3Session missing")
if "onAuthenticated={authenticate}" in text:
    raise SystemExit("Patch incomplete: AuthScreen gate still present")
if 'onClick={signOut}>Sign out</button>' in text:
    raise SystemExit("Patch incomplete: Sign out button still present")
if "Kiosk · always signed in" not in text:
    raise SystemExit("Patch incomplete: kiosk label missing")

app_path.write_text(text)
print("APP_PATCHED")
PY

  printf '%s\n' "$CRED_FINGERPRINT" > "$MARKER"
  ok "Patched App.tsx (skip AuthScreen)"
fi

log "Restarting evox3-jinhua-web.service"
systemctl --user restart evox3-jinhua-web.service

log "Waiting for frontend http://127.0.0.1:${EVOX3_WEB_PORT}"
READY=0
for _ in $(seq 1 90); do
  if curl -fsS "http://127.0.0.1:${EVOX3_WEB_PORT}" >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
[ "$READY" -eq 1 ] || warn "Frontend not ready yet — check journalctl --user -u evox3-jinhua-web"

ok "11_skip_auth_ui.sh complete — no Register/Login UI"
printf '\nNext:\n'
printf '  ./scripts/evox3/10_relaunch_kiosk.sh\n'
printf '  Expect dashboard/chat (account %s)\n' "$EVOX3_LOCAL_EMAIL"
printf 'Restore upstream AuthScreen: cp %s %s && systemctl --user restart evox3-jinhua-web\n' \
  "$APP_BAK" "$APP_TSX"
