#!/usr/bin/env bash
# Install ANGELICA stdio MCP server (remember/recall/connect/analyze).
# Idempotent. Requires Jinhua venv + optional mcp>=1.2,<2.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3

PATCH_DIR="$SCRIPT_DIR/patches/mcp_angelica"
PATCH_VER="1"
MARKER="$EVOX3_JINHUA_DIR/.evox3-mcp-angelica"

API_CLIENT_SRC="$PATCH_DIR/angelica_api_client.py"
SERVER_SRC="$PATCH_DIR/angelica_mcp_server.py"
SCRIPTS_DST="$EVOX3_JINHUA_DIR/scripts"
API_CLIENT_DST="$SCRIPTS_DST/angelica_api_client.py"
SERVER_DST="$SCRIPTS_DST/angelica_mcp_server.py"
VENV_PY="$EVOX3_JINHUA_DIR/.venv/bin/python"
CURSOR_EXAMPLE="$SCRIPT_DIR/../../docs/mcp_cursor_angelica.json.example"

[ -d "$EVOX3_JINHUA_DIR" ] || die "Missing $EVOX3_JINHUA_DIR — run 02 first"
[ -f "$API_CLIENT_SRC" ] || die "Missing patch $API_CLIENT_SRC"
[ -f "$SERVER_SRC" ] || die "Missing patch $SERVER_SRC"
[ -x "$VENV_PY" ] || die "Missing $VENV_PY — run 04_install_python_deps.sh first"

FINGERPRINT="$(
  cat "$API_CLIENT_SRC" "$SERVER_SRC" | sha256sum | awk '{print $1}'
)"

NEED_INSTALL=1
if [ -f "$MARKER" ] \
  && grep -q "^version=${PATCH_VER}$" "$MARKER" 2>/dev/null \
  && grep -q "^fingerprint=${FINGERPRINT}$" "$MARKER" 2>/dev/null \
  && [ -f "$SERVER_DST" ] \
  && grep -q 'EVOX3_MCP_ANGELICA' "$SERVER_DST" 2>/dev/null; then
  NEED_INSTALL=0
  ok "MCP ANGELICA server already installed (v${PATCH_VER})"
fi

if [ "$NEED_INSTALL" = "1" ]; then
  mkdir -p "$SCRIPTS_DST"
  install -m 0644 "$API_CLIENT_SRC" "$API_CLIENT_DST"
  install -m 0755 "$SERVER_SRC" "$SERVER_DST"
  ok "Installed MCP payloads into $SCRIPTS_DST"

  log "Ensuring mcp>=1.2,<2 in Jinhua venv"
  "$VENV_PY" -m pip install -q "mcp>=1.2,<2" \
    -i "$EVOX3_PIP_INDEX" --extra-index-url "$EVOX3_PIP_INDEX_FALLBACK" \
    || "$VENV_PY" -m pip install -q "mcp>=1.2,<2"

  if ! "$VENV_PY" -c 'from mcp.server.fastmcp import FastMCP' 2>/dev/null; then
    die "mcp FastMCP import failed after pip install"
  fi
  ok "Jinhua venv has FastMCP (mcp>=1.2,<2)"

  cat >"$MARKER" <<EOF
version=${PATCH_VER}
fingerprint=${FINGERPRINT}
server=${SERVER_DST}
venv_python=${VENV_PY}
EOF
  ok "Wrote marker $MARKER"
fi

# Machine-specific Cursor snippet (paths expanded on EVO-X3).
THOMA_DOCS="$(cd "$SCRIPT_DIR/../.." && pwd)/docs"
mkdir -p "$THOMA_DOCS"
cat >"$THOMA_DOCS/mcp_cursor_angelica.generated.json" <<EOF
{
  "mcpServers": {
    "angelica": {
      "command": "${VENV_PY}",
      "args": ["${SERVER_DST}"],
      "env": {
        "ANGELICA_API_URL": "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}",
        "ANGELICA_EMAIL": "${EVOX3_LOCAL_EMAIL}",
        "ANGELICA_PASSWORD": "${EVOX3_LOCAL_PASSWORD}"
      }
    }
  }
}
EOF
ok "Wrote Cursor MCP snippet $THOMA_DOCS/mcp_cursor_angelica.generated.json"

ok "18_mcp_angelica.sh complete"
printf '  Tools: remember, recall, connect, analyze\n'
printf '  Demo: ./scripts/evox3/18_demo_mcp.sh\n'
printf '  Cursor: copy docs/mcp_cursor_angelica.generated.json into MCP settings\n'
printf '  analyze requires: ./scripts/evox3/17_graph_analytics.sh\n'
