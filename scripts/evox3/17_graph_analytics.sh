#!/usr/bin/env bash
# Patch Jinhua with Neo4j graph analytics APIs (orphans, PageRank, Louvain,
# bridges, shortest-path). Stdlib only — no GDS / networkx.
# Idempotent. Restarts evox3-jinhua-api after apply.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3
require_cmd curl
require_cmd systemctl

PATCH_DIR="$SCRIPT_DIR/patches/graph_analytics"
PATCH_VER="1"
MARKER="$EVOX3_JINHUA_DIR/.evox3-graph-analytics"

ANALYTICS_SRC="$PATCH_DIR/analytics.py"
ROUTER_SRC="$PATCH_DIR/graph_router.py"
SCHEMAS_SRC="$PATCH_DIR/graph_schemas.py"

ANALYTICS_DST="$EVOX3_JINHUA_DIR/secondbrain/graph/analytics.py"
ROUTER_DST="$EVOX3_JINHUA_DIR/apps/api/routers/graph.py"
SCHEMAS_DST="$EVOX3_JINHUA_DIR/apps/api/schemas/graph.py"

[ -d "$EVOX3_JINHUA_DIR" ] || die "Missing $EVOX3_JINHUA_DIR — run 02 first"
[ -f "$ANALYTICS_SRC" ] || die "Missing patch payload $ANALYTICS_SRC"
[ -f "$ROUTER_SRC" ] || die "Missing patch payload $ROUTER_SRC"
[ -f "$SCHEMAS_SRC" ] || die "Missing patch payload $SCHEMAS_SRC"
[ -d "$(dirname "$ANALYTICS_DST")" ] || die "Missing secondbrain/graph — is Jinhua cloned?"
[ -f "$ROUTER_DST" ] || die "Missing $ROUTER_DST"
[ -f "$SCHEMAS_DST" ] || die "Missing $SCHEMAS_DST"

FINGERPRINT="$(
  cat "$ANALYTICS_SRC" "$ROUTER_SRC" "$SCHEMAS_SRC" | sha256sum | awk '{print $1}'
)"

NEED_PATCH=1
if [ -f "$MARKER" ] \
  && grep -q "^version=${PATCH_VER}$" "$MARKER" 2>/dev/null \
  && grep -q "^fingerprint=${FINGERPRINT}$" "$MARKER" 2>/dev/null \
  && [ -f "$ANALYTICS_DST" ] \
  && grep -q 'EVOX3_GRAPH_ANALYTICS' "$ANALYTICS_DST" 2>/dev/null \
  && grep -q 'EVOX3_GRAPH_ANALYTICS' "$ROUTER_DST" 2>/dev/null \
  && grep -q 'EVOX3_GRAPH_ANALYTICS' "$SCHEMAS_DST" 2>/dev/null; then
  NEED_PATCH=0
  ok "Graph analytics patch already applied (v${PATCH_VER})"
fi

if [ "$NEED_PATCH" = "1" ]; then
  for pair in \
    "$ROUTER_DST|$ROUTER_DST.evox3-graph-orig" \
    "$SCHEMAS_DST|$SCHEMAS_DST.evox3-graph-orig"; do
    src="${pair%%|*}"
    bak="${pair##*|}"
    if [ ! -f "$bak" ]; then
      cp "$src" "$bak"
      # Show parent/name — both files are named graph.py
      ok "Backed up $(basename "$(dirname "$src")")/$(basename "$src") -> $(basename "$bak")"
    fi
  done

  install -m 0644 "$ANALYTICS_SRC" "$ANALYTICS_DST"
  install -m 0644 "$ROUTER_SRC" "$ROUTER_DST"
  install -m 0644 "$SCHEMAS_SRC" "$SCHEMAS_DST"
  ok "Installed graph analytics payloads into Jinhua clone"

  cat >"$MARKER" <<EOF
version=${PATCH_VER}
fingerprint=${FINGERPRINT}
engine=evox3-stdlib
EOF
  ok "Wrote marker $MARKER"
fi

if [ "$NEED_PATCH" = "1" ]; then
  if systemctl --user is-active --quiet evox3-jinhua-api.service 2>/dev/null; then
    log "Restarting evox3-jinhua-api.service"
    systemctl --user restart evox3-jinhua-api.service
    log "Waiting for API docs http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/docs"
    READY=0
    for _ in $(seq 1 90); do
      if curl -fsS "http://${EVOX3_API_HOST}:${EVOX3_API_PORT}/docs" >/dev/null 2>&1; then
        READY=1
        break
      fi
      sleep 1
    done
    if [ "$READY" -eq 1 ]; then
      ok "API ready on :${EVOX3_API_PORT}"
    else
      warn "API not ready yet — check journalctl --user -u evox3-jinhua-api"
    fi
  else
    warn "evox3-jinhua-api.service not active — start via 06 if needed"
  fi
else
  log "No graph analytics file changes — skip API restart"
fi

ok "17_graph_analytics.sh complete"
printf '  Endpoints (Bearer auth):\n'
printf '    GET /graph/analytics/summary\n'
printf '    GET /graph/analytics/orphans\n'
printf '    GET /graph/analytics/pagerank\n'
printf '    GET /graph/analytics/communities\n'
printf '    GET /graph/analytics/bridges\n'
printf '    GET /graph/analytics/shortest-path?source_id=&target_id=\n'
printf '  Restore: cp %s.evox3-graph-orig over graph.py/schemas; rm %s\n' \
  "apps/api/routers/graph.py" "$ANALYTICS_DST"
printf '  Demo (no manual TOKEN paste):\n'
printf '    ./scripts/evox3/17_demo_analytics.sh\n'
printf '  Smoke: ./scripts/evox3/09_smoke_check.sh\n'
