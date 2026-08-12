#!/usr/bin/env bash
# Brand the Jinhua web UI as ANGELICA (title, sidebar, Greek footer prompts).
# Idempotent. Run on EVO-X3 against ~/ai_apps/IncubativeSecondBrain.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3
require_cmd systemctl
require_cmd curl

WEB_DIR="$EVOX3_JINHUA_DIR/apps/web"
INDEX_HTML="$WEB_DIR/index.html"
SIDEBAR="$WEB_DIR/src/components/AppSidebar.tsx"
APP_TSX="$WEB_DIR/src/App.tsx"
MARKER="$WEB_DIR/.evox3-brand-angelica"
EVOX3_BRAND_VERSION="1"

[ -d "$WEB_DIR" ] || die "Missing $WEB_DIR — run 02 first"
[ -f "$INDEX_HTML" ] || die "Missing $INDEX_HTML"
[ -f "$SIDEBAR" ] || die "Missing $SIDEBAR"
[ -f "$APP_TSX" ] || die "Missing $APP_TSX"

FINGERPRINT="$(
  printf '%s|%s|%s|%s|%s' \
    "$EVOX3_BRAND_VERSION" \
    "$EVOX3_BRAND_NAME" \
    "$EVOX3_BRAND_TAGLINE" \
    "$EVOX3_BRAND_MARK" \
    "$EVOX3_BRAND_TITLE" | sha256sum | awk '{print $1}'
)"

NEED_PATCH=1
if [ -f "$MARKER" ] && grep -q "^version=${EVOX3_BRAND_VERSION}$" "$MARKER" 2>/dev/null \
  && grep -q "^fingerprint=${FINGERPRINT}$" "$MARKER" 2>/dev/null \
  && grep -q "$EVOX3_BRAND_NAME" "$SIDEBAR" 2>/dev/null \
  && grep -q "$EVOX3_BRAND_NAME" "$INDEX_HTML" 2>/dev/null; then
  NEED_PATCH=0
  ok "ANGELICA brand patch already applied (v${EVOX3_BRAND_VERSION})"
fi

# Force refresh if upstream SecondBrain title still visible.
if grep -q 'dash-logo-title">SecondBrain<' "$SIDEBAR" 2>/dev/null; then
  log "Upstream SecondBrain title still present — forcing brand refresh"
  NEED_PATCH=1
fi

if [ "$NEED_PATCH" = "1" ]; then
  for f in "$INDEX_HTML" "$SIDEBAR" "$APP_TSX"; do
    bak="${f}.evox3-brand-orig"
    if [ ! -f "$bak" ]; then
      cp "$f" "$bak"
      ok "Backed up $(basename "$f") -> $(basename "$bak")"
    fi
  done

  # Prefer pristine brand backups so re-runs stay clean (skip-auth may have changed App.tsx).
  INDEX_SRC="$INDEX_HTML"
  [ -f "${INDEX_HTML}.evox3-brand-orig" ] && INDEX_SRC="${INDEX_HTML}.evox3-brand-orig"
  SIDEBAR_SRC="$SIDEBAR"
  [ -f "${SIDEBAR}.evox3-brand-orig" ] && SIDEBAR_SRC="${SIDEBAR}.evox3-brand-orig"
  # App.tsx: patch live file (may already include EVOX3_SKIP_AUTH). Only replace FOOTER_PROMPTS.

  BRAND_NAME="$EVOX3_BRAND_NAME" \
  BRAND_TAGLINE="$EVOX3_BRAND_TAGLINE" \
  BRAND_MARK="$EVOX3_BRAND_MARK" \
  BRAND_TITLE="$EVOX3_BRAND_TITLE" \
  INDEX_SRC="$INDEX_SRC" INDEX_DST="$INDEX_HTML" \
  SIDEBAR_SRC="$SIDEBAR_SRC" SIDEBAR_DST="$SIDEBAR" \
  APP_TSX="$APP_TSX" \
  python3 - <<'PY'
import os
import re
from pathlib import Path

brand = os.environ["BRAND_NAME"]
tagline = os.environ["BRAND_TAGLINE"]
mark = os.environ["BRAND_MARK"]
title = os.environ["BRAND_TITLE"]

# --- index.html ---
index = Path(os.environ["INDEX_SRC"]).read_text()
index2, n = re.subn(
    r"<title>[^<]*</title>",
    f"<title>{title}</title>",
    index,
    count=1,
)
if n != 1:
    raise SystemExit("Could not patch <title> in index.html")
Path(os.environ["INDEX_DST"]).write_text(index2)

# --- AppSidebar.tsx ---
sidebar = Path(os.environ["SIDEBAR_SRC"]).read_text()
sidebar2, n = re.subn(
    r'(<div className="dash-logo">)[^<]*(</div>)',
    rf"\g<1>{mark}\g<2>",
    sidebar,
    count=1,
)
if n != 1:
    raise SystemExit("Could not patch dash-logo mark in AppSidebar.tsx")
sidebar = sidebar2
sidebar2, n = re.subn(
    r'(<div className="dash-logo-title">)[^<]*(</div>)',
    rf"\g<1>{brand}\g<2>",
    sidebar,
    count=1,
)
if n != 1:
    raise SystemExit("Could not patch dash-logo-title in AppSidebar.tsx")
sidebar = sidebar2
sidebar2, n = re.subn(
    r'(<div className="dash-logo-sub">)[^<]*(</div>)',
    rf"\g<1>{tagline}\g<2>",
    sidebar,
    count=1,
)
if n != 1:
    raise SystemExit("Could not patch dash-logo-sub in AppSidebar.tsx")
Path(os.environ["SIDEBAR_DST"]).write_text(sidebar2)

# --- App.tsx FOOTER_PROMPTS (Greek) ---
app_path = Path(os.environ["APP_TSX"])
app = app_path.read_text()
prompts = f'''const FOOTER_PROMPTS = [
  "Ποιος είναι ο kiosk χρήστης στο {brand};",
  "Συνόψισε τι ξέρεις για το {brand}",
  "Τι σημειώσεις έχω για το EVO-X3;",
];'''
app2, n = re.subn(
    r"const FOOTER_PROMPTS = \[[^\]]*\];",
    prompts,
    app,
    count=1,
    flags=re.S,
)
if n != 1:
    raise SystemExit("Could not patch FOOTER_PROMPTS in App.tsx")
app_path.write_text(app2)
print("BRAND_PATCH_OK")
PY

  cat >"$MARKER" <<EOF
version=${EVOX3_BRAND_VERSION}
fingerprint=${FINGERPRINT}
brand=${EVOX3_BRAND_NAME}
tagline=${EVOX3_BRAND_TAGLINE}
EOF
  ok "Wrote brand marker $MARKER"
fi

# Restart only when files changed. Always wait for :5173 so immediate 09 smoke
# does not race Vite cold-start (seen as Web UI HTTP 000).
if [ "$NEED_PATCH" = "1" ]; then
  if systemctl --user is-active --quiet evox3-jinhua-web.service 2>/dev/null; then
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
    if [ "$READY" -eq 1 ]; then
      ok "Frontend ready on :${EVOX3_WEB_PORT}"
    else
      warn "Frontend not ready yet — check journalctl --user -u evox3-jinhua-web"
    fi
  else
    warn "evox3-jinhua-web.service not active — start via 07 if needed"
  fi
else
  log "No brand file changes — skip web restart"
fi

ok "16_brand_angelica.sh complete — UI brand ${EVOX3_BRAND_NAME}"
printf '  Title: %s\n' "$EVOX3_BRAND_TITLE"
printf '  Sidebar: %s / %s\n' "$EVOX3_BRAND_NAME" "$EVOX3_BRAND_TAGLINE"
printf '  Restore: cp %s.evox3-brand-orig files back under %s\n' "*" "$WEB_DIR"
