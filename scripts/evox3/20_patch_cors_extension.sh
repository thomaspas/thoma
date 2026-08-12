#!/usr/bin/env bash
# Patch Jinhua FastAPI CORS for ANGELICA Capture chrome-extension:// origins.
# Idempotent. Restarts evox3-jinhua-api after apply.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3
require_cmd systemctl

MAIN_PY="$EVOX3_JINHUA_DIR/apps/api/main.py"
BAK="$EVOX3_JINHUA_DIR/apps/api/main.py.evox3-cors-orig"
MARKER="$EVOX3_JINHUA_DIR/.evox3-cors-extension"
PATCH_VER="1"
SNIPPET="$SCRIPT_DIR/patches/cors_extension/main_cors_snippet.py"

[ -f "$MAIN_PY" ] || die "Missing $MAIN_PY — is Jinhua cloned?"

if [ -f "$MARKER" ] && [ "$(tr -d '[:space:]' <"$MARKER")" = "$PATCH_VER" ] \
  && grep -q 'EVOX3_CORS_EXTENSION' "$MAIN_PY" 2>/dev/null; then
  ok "CORS extension patch already applied (v${PATCH_VER})"
  exit 0
fi

if [ ! -f "$BAK" ]; then
  cp "$MAIN_PY" "$BAK"
  ok "Backed up main.py -> main.py.evox3-cors-orig"
fi

python3 - "$MAIN_PY" "$SNIPPET" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
snippet_path = Path(sys.argv[2])
text = path.read_text()
ns: dict = {}
exec(snippet_path.read_text(), ns)
old, new = ns["OLD"], ns["NEW"]
if "EVOX3_CORS_EXTENSION" in text and "allow_origin_regex" in text:
    print("ALREADY")
    sys.exit(0)
if old not in text:
    raise SystemExit("Could not locate CORSMiddleware block in main.py")
text = text.replace(old, new, 1)
if "EVOX3_CORS_EXTENSION" not in text:
    raise SystemExit("Patch marker missing after replace")
path.write_text(text)
print("PATCHED")
PY

printf '%s\n' "$PATCH_VER" >"$MARKER"
ok "Patched $MAIN_PY (chrome-extension CORS)"

log "Restarting evox3-jinhua-api.service"
systemctl --user restart evox3-jinhua-api.service || warn "Could not restart API unit"
ok "20_patch_cors_extension.sh complete"
