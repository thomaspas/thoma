#!/usr/bin/env bash
# Install ANGELICA Capture browser extension (MV3, no npm build).
# Copies source to build/chrome-mv3-prod for Load unpacked.
# Optional: apply CORS patch for chrome-extension origins on the API.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

EXT_DIR="$(cd "$SCRIPT_DIR/../../extensions/angelica-capture" && pwd)"
BUILD_DIR="$EXT_DIR/build/chrome-mv3-prod"
MARKER="$EXT_DIR/.evox3-built"

require_cmd cp

if [ "${EVOX3_SKIP_CORS_PATCH:-0}" != "1" ]; then
  bash "$SCRIPT_DIR/20_patch_cors_extension.sh" || warn "CORS patch skipped/failed — host_permissions usually suffice"
fi

[ -f "$EXT_DIR/manifest.json" ] || die "Missing $EXT_DIR/manifest.json"

log "Staging extension to $BUILD_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
for item in manifest.json background.js popup.html popup.js assets lib; do
  [ -e "$EXT_DIR/$item" ] || continue
  cp -a "$EXT_DIR/$item" "$BUILD_DIR/"
done

[ -f "$BUILD_DIR/manifest.json" ] || die "Staging failed"

date -u +%Y-%m-%dT%H:%M:%SZ >"$MARKER"

ok "Extension staged: $BUILD_DIR"
printf '\nLoad unpacked in Chromium:\n'
printf '  1) chrome://extensions → Developer mode → Load unpacked\n'
printf '  2) Select: %s\n' "$BUILD_DIR"
printf '  3) Configure API URL / credentials in the extension popup if needed\n'
printf '  4) Right-click page → Capture page to ANGELICA\n'
ok "19_browser_extension.sh complete"
