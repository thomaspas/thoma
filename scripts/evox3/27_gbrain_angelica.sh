#!/usr/bin/env bash
# Install GBrain (GitHub via Bun), init PGLite in ~/gbrain-agent, write ANGELICA
# identity, enable user unit angelica-gbrain.service (gbrain serve --http).
# Idempotent. Run on EVO-X3. NEVER npm install -g gbrain.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

IDENTITY_DIR="$SCRIPT_DIR/gbrain_identity"
MARKER="$EVOX3_GBRAIN_HOME/.evox3-angelica-gbrain"
export GBRAIN_NO_ONBOARD_NUDGE=1

assert_gbrain_home_not_thoma "$EVOX3_GBRAIN_HOME"
ensure_dir "$EVOX3_GBRAIN_HOME"

persist_bun_path() {
  local line='export PATH="$HOME/.bun/bin:$PATH"'
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$rc" ] && grep -Fq '.bun/bin' "$rc"; then
      continue
    fi
    if [ -f "$rc" ] || [ "$rc" = "$HOME/.bashrc" ]; then
      printf '\n# bun (ANGELICA GBrain)\n%s\n' "$line" >>"$rc"
      ok "Added bun PATH to $rc"
    fi
  done
}

install_bun() {
  ensure_bun_on_path
  if command -v bun >/dev/null 2>&1; then
    ok "bun already on PATH: $(command -v bun)"
    persist_bun_path
    return 0
  fi
  if [ -x "$HOME/.bun/bin/bun" ]; then
    ensure_bun_on_path
    persist_bun_path
    ok "bun found at $HOME/.bun/bin/bun"
    return 0
  fi
  require_cmd curl
  log "Installing bun"
  curl -fsSL https://bun.sh/install | bash
  ensure_bun_on_path
  persist_bun_path
  command -v bun >/dev/null 2>&1 || die "bun install finished but bun is not on PATH"
  ok "Installed bun $(bun --version)"
}

warn_npm_shadow() {
  local npm_root=""
  if command -v npm >/dev/null 2>&1; then
    npm_root="$(npm root -g 2>/dev/null || true)"
    if [ -n "$npm_root" ] && [ -d "${npm_root}/gbrain" ]; then
      warn "npm global package 'gbrain' is present at ${npm_root}/gbrain"
      warn "That is NOT Garry Tan GBrain. Run: npm uninstall -g gbrain"
    fi
  fi
}

gbrain_from_github() {
  ensure_bun_on_path
  local gb
  gb="$(command -v gbrain 2>/dev/null || true)"
  if [ -n "$gb" ]; then
    case "$gb" in
      *node_modules/gbrain*|*npm/gbrain*)
        warn "PATH gbrain looks like npm-shadow: $gb"
        ;;
      *)
        ok "gbrain already installed: $gb"
        "$gb" --version || true
        return 0
        ;;
    esac
  fi

  log "Installing GBrain from GitHub (bun install -g github:garrytan/gbrain)"
  log "NEVER: npm install -g gbrain / bun add -g gbrain (unrelated npm package)"
  if bun install -g github:garrytan/gbrain; then
    ensure_bun_on_path
    command -v gbrain >/dev/null 2>&1 || die "bun install -g succeeded but gbrain not on PATH"
    ok "Installed $(gbrain --version 2>/dev/null || printf gbrain)"
    return 0
  fi

  warn "bun install -g github:garrytan/gbrain failed — clone + bun link fallback"
  if [ ! -d "$HOME/gbrain/.git" ]; then
    git clone https://github.com/garrytan/gbrain.git "$HOME/gbrain"
  fi
  (
    cd "$HOME/gbrain"
    bun install
    bun link
  )
  ensure_bun_on_path
  command -v gbrain >/dev/null 2>&1 || die "gbrain still missing after bun link"
  if gbrain apply-migrations --yes >/dev/null 2>&1; then
    ok "gbrain apply-migrations --yes"
  fi
  ok "Linked gbrain from $HOME/gbrain"
}

init_pglite() {
  local args=(init --pglite)
  ensure_bun_on_path
  cd "$EVOX3_GBRAIN_HOME"

  if [ -n "${OPENAI_API_KEY:-}" ] || [ -n "${ZEROENTROPY_API_KEY:-}" ] || [ -n "${VOYAGE_API_KEY:-}" ]; then
    log "Embedding API key present in environment — gbrain init will auto-detect"
  else
    args+=(--no-embedding)
    log "No embedding API keys — keyless PGLite (--no-embedding). Keyword search still works."
  fi

  if [ -f "$HOME/.gbrain/config.json" ]; then
    ok "GBrain already initialized (~/.gbrain/config.json) — skipping init"
    return 0
  fi

  log "gbrain ${args[*]} in $EVOX3_GBRAIN_HOME"
  gbrain "${args[@]}"
  ok "gbrain init complete"
}

write_identity() {
  local f src dst
  for f in SOUL.md USER.md MEMORY.md; do
    src="$IDENTITY_DIR/$f"
    dst="$EVOX3_GBRAIN_HOME/$f"
    [ -f "$src" ] || die "Missing identity template $src"
    if [ -f "$dst" ]; then
      ok "Keeping existing $dst"
    else
      cp "$src" "$dst"
      ok "Wrote $dst (ANGELICA identity)"
    fi
  done
}

import_identity() {
  ensure_bun_on_path
  if gbrain import "$EVOX3_GBRAIN_HOME" --no-embed >/dev/null 2>&1; then
    ok "Imported identity markdown into GBrain (--no-embed)"
  else
    warn "gbrain import skipped or failed (non-fatal). Files remain in $EVOX3_GBRAIN_HOME"
  fi
}

install_serve_unit() {
  local unit_dir unit_path
  require_cmd systemctl
  ensure_bun_on_path
  command -v gbrain >/dev/null 2>&1 || die "gbrain not on PATH for systemd unit"

  unit_dir="$(user_systemd_dir)"
  unit_path="$unit_dir/$EVOX3_GBRAIN_UNIT"

  # Always-on Level 5 is HTTP MCP (stdio gbrain serve is for Cursor subprocess).
  cat >"$unit_path" <<EOF
[Unit]
Description=ANGELICA GBrain Level 5 (gbrain serve --http)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${EVOX3_GBRAIN_HOME}
Environment=HOME=${HOME}
Environment=PATH=${HOME}/.bun/bin:${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin
Environment=GBRAIN_NO_ONBOARD_NUDGE=1
ExecStart=/bin/bash -lc 'exec gbrain serve --http --port ${EVOX3_GBRAIN_HTTP_PORT} --bind ${EVOX3_GBRAIN_HTTP_BIND}'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
  reload_user_systemd
  enable_linger_hint
  systemctl --user enable --now "$EVOX3_GBRAIN_UNIT"
  ok "Enabled $EVOX3_GBRAIN_UNIT (HTTP ${EVOX3_GBRAIN_HTTP_BIND}:${EVOX3_GBRAIN_HTTP_PORT})"
  log "Cursor MCP is separate: stdio 'gbrain serve' (see docs/mcp_cursor_gbrain.json.example)"
}

write_marker() {
  cat >"$MARKER" <<EOF
brand=${EVOX3_BRAND_NAME}
workspace=${EVOX3_GBRAIN_HOME}
unit=${EVOX3_GBRAIN_UNIT}
http=${EVOX3_GBRAIN_HTTP_BIND}:${EVOX3_GBRAIN_HTTP_PORT}
EOF
  ok "Wrote $MARKER"
}

install_bun
warn_npm_shadow
gbrain_from_github
init_pglite
write_identity
import_identity
install_serve_unit
write_marker

ok "27_gbrain_angelica.sh complete"
printf '  Workspace: %s\n' "$EVOX3_GBRAIN_HOME"
printf '  Identity: SOUL.md USER.md MEMORY.md (name ANGELICA)\n'
printf '  Unit: %s\n' "$EVOX3_GBRAIN_UNIT"
printf '  Next: ./scripts/evox3/28_gbrain_verify.sh\n'
