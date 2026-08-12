#!/usr/bin/env bash
# Install full-bleed React Flow Graph workspace (sidebar NavId "graph").
# Idempotent. Run on EVO-X3 against ~/ai_apps/IncubativeSecondBrain.
# Does not change LLM /.env. Leaves Overview DashboardGraph (3D) intact.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3
require_cmd systemctl
require_cmd curl
require_cmd npm

PATCH_DIR="$SCRIPT_DIR/patches/graph_ui"
PATCH_VER="1"
WEB_DIR="$EVOX3_JINHUA_DIR/apps/web"
SRC_DIR="$WEB_DIR/src"
APP_TSX="$SRC_DIR/App.tsx"
SIDEBAR="$SRC_DIR/components/AppSidebar.tsx"
INDEX_CSS="$SRC_DIR/index.css"
PKG_JSON="$WEB_DIR/package.json"
MARKER="$WEB_DIR/.evox3-graph-ui-reactflow"
WORKSPACE_SRC="$PATCH_DIR/GraphFlowWorkspace.tsx"
CSS_SRC="$PATCH_DIR/graph_flow.css"
WORKSPACE_DST="$SRC_DIR/features/graph/GraphFlowWorkspace.tsx"
GRAPH_FEAT_DIR="$SRC_DIR/features/graph"

[ -d "$WEB_DIR" ] || die "Missing $WEB_DIR — run 02 first"
[ -f "$APP_TSX" ] || die "Missing $APP_TSX"
[ -f "$SIDEBAR" ] || die "Missing $SIDEBAR"
[ -f "$INDEX_CSS" ] || die "Missing $INDEX_CSS"
[ -f "$PKG_JSON" ] || die "Missing $PKG_JSON"
[ -f "$WORKSPACE_SRC" ] || die "Missing patch payload $WORKSPACE_SRC"
[ -f "$CSS_SRC" ] || die "Missing patch payload $CSS_SRC"
[ -d "$GRAPH_FEAT_DIR" ] || die "Missing $GRAPH_FEAT_DIR — unexpected Jinhua layout"

FINGERPRINT="$(
  cat "$WORKSPACE_SRC" "$CSS_SRC" "$SCRIPT_DIR/24_graph_ui_reactflow.sh" | sha256sum | awk '{print $1}'
)"

NEED_PATCH=1
if [ -f "$MARKER" ] \
  && grep -q "^version=${PATCH_VER}$" "$MARKER" 2>/dev/null \
  && grep -q "^fingerprint=${FINGERPRINT}$" "$MARKER" 2>/dev/null \
  && [ -f "$WORKSPACE_DST" ] \
  && grep -q 'EVOX3_GRAPH_UI' "$WORKSPACE_DST" 2>/dev/null \
  && grep -q 'EVOX3_GRAPH_UI' "$APP_TSX" 2>/dev/null \
  && grep -q '"graph"' "$SIDEBAR" 2>/dev/null \
  && grep -q 'EVOX3_GRAPH_UI_BEGIN' "$INDEX_CSS" 2>/dev/null \
  && grep -q '@xyflow/react' "$PKG_JSON" 2>/dev/null; then
  NEED_PATCH=0
  ok "Graph UI React Flow patch already applied (v${PATCH_VER})"
fi

if [ -f "$MARKER" ] && ! grep -q 'GraphFlowWorkspace' "$APP_TSX" 2>/dev/null; then
  log "Marker present but App.tsx missing GraphFlowWorkspace — forcing refresh"
  NEED_PATCH=1
fi

if [ "$NEED_PATCH" = "1" ]; then
  for f in "$APP_TSX" "$SIDEBAR" "$INDEX_CSS" "$PKG_JSON"; do
    bak="${f}.evox3-graph-ui-orig"
    if [ ! -f "$bak" ]; then
      cp "$f" "$bak"
      ok "Backed up $(basename "$(dirname "$f")")/$(basename "$f") -> $(basename "$bak")"
    fi
  done
  if [ -f "$WEB_DIR/package-lock.json" ] && [ ! -f "$WEB_DIR/package-lock.json.evox3-graph-ui-orig" ]; then
    cp "$WEB_DIR/package-lock.json" "$WEB_DIR/package-lock.json.evox3-graph-ui-orig"
    ok "Backed up package-lock.json"
  fi

  install -m 0644 "$WORKSPACE_SRC" "$WORKSPACE_DST"
  ok "Installed GraphFlowWorkspace.tsx"

  APP_TSX="$APP_TSX" SIDEBAR="$SIDEBAR" INDEX_CSS="$INDEX_CSS" CSS_SRC="$CSS_SRC" \
  python3 - <<'PY'
import os
import re
from pathlib import Path

app_path = Path(os.environ["APP_TSX"])
sidebar_path = Path(os.environ["SIDEBAR"])
css_path = Path(os.environ["INDEX_CSS"])
css_snip = Path(os.environ["CSS_SRC"]).read_text()

# --- AppSidebar.tsx ---
sb = sidebar_path.read_text()
if '| "graph"' not in sb and "id: \"graph\"" not in sb:
    sb2, n = re.subn(
        r'(export type NavId =\s*\n\s*\|\s*"overview")',
        r'\1\n  | "graph" // EVOX3_GRAPH_UI',
        sb,
        count=1,
    )
    if n != 1:
        raise SystemExit("Could not patch NavId union in AppSidebar.tsx")
    sb = sb2
    sb2, n = re.subn(
        r'(\{ id: "overview", label: "Overview", icon: "[^"]*" \},)',
        r'\1\n  { id: "graph", label: "Graph", icon: "◎" }, // EVOX3_GRAPH_UI',
        sb,
        count=1,
    )
    if n != 1:
        raise SystemExit("Could not patch NAV array in AppSidebar.tsx")
    sidebar_path.write_text(sb2)
    print("SIDEBAR_PATCH_OK")
else:
    print("SIDEBAR_ALREADY_OK")

# --- App.tsx ---
app = app_path.read_text()

if 'import GraphFlowWorkspace from "./features/graph/GraphFlowWorkspace"' not in app:
    app2, n = re.subn(
        r'(import DashboardGraph from "./features/dashboard/DashboardGraph";)',
        r'\1\nimport GraphFlowWorkspace from "./features/graph/GraphFlowWorkspace"; // EVOX3_GRAPH_UI',
        app,
        count=1,
    )
    if n != 1:
        raise SystemExit("Could not insert GraphFlowWorkspace import in App.tsx")
    app = app2
    print("APP_IMPORT_OK")
else:
    if "EVOX3_GRAPH_UI" not in app:
        app = app.replace(
            'import GraphFlowWorkspace from "./features/graph/GraphFlowWorkspace";',
            'import GraphFlowWorkspace from "./features/graph/GraphFlowWorkspace"; // EVOX3_GRAPH_UI',
            1,
        )
    print("APP_IMPORT_ALREADY")

if 'id === "graph"' not in app:
    app2, n = re.subn(
        r'(function handleNav\(id: NavId\) \{\s*\n\s*setActiveNav\(id\);\s*\n)',
        r'\1    if (id === "graph") {\n      setDrawer(null);\n      return; // EVOX3_GRAPH_UI\n    }\n',
        app,
        count=1,
    )
    if n != 1:
        raise SystemExit("Could not patch handleNav for graph in App.tsx")
    app = app2
    print("APP_HANDLENAV_OK")
else:
    print("APP_HANDLENAV_ALREADY")

if "graph-flow-mode" not in app:
    start = app.find('<div className="dashboard-main">')
    if start < 0:
        raise SystemExit("dashboard-main not found")
    grid_start = app.find('<div className="dashboard-grid">', start)
    footer_start = app.find('<footer className="dash-footer">', start)
    if grid_start < 0 or footer_start < 0 or grid_start > footer_start:
        raise SystemExit("dashboard-grid / footer anchors not found")

    i = grid_start
    depth = 0
    grid_end = None
    while i < footer_start:
        if app.startswith("<div", i):
            depth += 1
            gt = app.find(">", i)
            i = gt + 1 if gt >= 0 else i + 1
            continue
        if app.startswith("</div>", i):
            depth -= 1
            if depth == 0:
                grid_end = i + len("</div>")
                break
            i += len("</div>")
            continue
        i += 1
    if grid_end is None:
        raise SystemExit("Could not find matching close for dashboard-grid")

    original_grid = app[grid_start:grid_end]
    replacement = (
        '{activeNav === "graph" ? (\n'
        '          <div className="dashboard-grid graph-flow-mode" data-evox3="graph-ui">{/* EVOX3_GRAPH_UI */}\n'
        '            <div className="dashboard-center graph-flow-center">\n'
        '              <GraphFlowWorkspace reloadSignal={reloadSignal} />\n'
        '            </div>\n'
        '          </div>\n'
        '        ) : (\n'
        f'          {original_grid}\n'
        '        )}'
    )
    app = app[:grid_start] + replacement + app[grid_end:]
    print("APP_GRID_OK")
else:
    print("APP_GRID_ALREADY")

app_path.write_text(app)

# --- index.css ---
css = css_path.read_text()
snip = css_snip if css_snip.endswith("\n") else css_snip + "\n"
if "EVOX3_GRAPH_UI_BEGIN" not in css:
    if not css.endswith("\n"):
        css += "\n"
    css += "\n" + snip
    css_path.write_text(css)
    print("CSS_PATCH_OK")
else:
    css2, n = re.subn(
        r"/\* EVOX3_GRAPH_UI_BEGIN.*?/\* EVOX3_GRAPH_UI_END \*/\n?",
        snip,
        css,
        count=1,
        flags=re.S,
    )
    if n == 1:
        css_path.write_text(css2)
        print("CSS_REFRESH_OK")
    else:
        print("CSS_ALREADY_OK")
PY

  log "Installing @xyflow/react in apps/web"
  (
    cd "$WEB_DIR"
    npm install '@xyflow/react@^12' --save
  ) || die "npm install @xyflow/react failed"

  if ! grep -q '@xyflow/react' "$PKG_JSON"; then
    die "@xyflow/react not present in package.json after npm install"
  fi
  ok "@xyflow/react present in package.json"

  cat >"$MARKER" <<EOF
version=${PATCH_VER}
fingerprint=${FINGERPRINT}
pkg=@xyflow/react
workspace=features/graph/GraphFlowWorkspace.tsx
EOF
  ok "Wrote marker $MARKER"
fi

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
  log "No graph UI file changes — skip web restart"
fi

ok "24_graph_ui_reactflow.sh complete"
printf '  Sidebar: Graph nav (NavId graph)\n'
printf '  Workspace: %s\n' "$WORKSPACE_DST"
printf '  Marker: %s\n' "$MARKER"
printf '  Restore: cp *.evox3-graph-ui-orig over live files; rm %s %s\n' \
  "$WORKSPACE_DST" "$MARKER"
printf '  Next: ./scripts/evox3/10_relaunch_kiosk.sh && ./scripts/evox3/21_remote_verify.sh\n'
