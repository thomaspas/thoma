#!/usr/bin/env bash
# Demo ANGELICA MCP tool flows without Cursor or TOKEN paste.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3

API="http://${EVOX3_API_HOST}:${EVOX3_API_PORT}"
EMAIL="${EVOX3_LOCAL_EMAIL}"
PASSWORD="${EVOX3_LOCAL_PASSWORD}"
CLIENT_PY="$EVOX3_JINHUA_DIR/scripts/angelica_api_client.py"

printf '\e[?2004l' 2>/dev/null || true

[ -f "$CLIENT_PY" ] || die "Missing $CLIENT_PY — run ./scripts/evox3/18_mcp_angelica.sh first"

python3 - "$API" "$EMAIL" "$PASSWORD" "$CLIENT_PY" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

api, email, password, client_path = sys.argv[1:5]
spec = importlib.util.spec_from_file_location("angelica_api_client", client_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
client = mod.AngelicaClient(api, email, password)

def preview(obj, n=200):
    return json.dumps(obj, ensure_ascii=False, default=str)[:n]

try:
    token = client.login()
    print(f"[+] login OK ({email}) token_len={len(token)}")
except mod.AngelicaApiError as exc:
    print(f"[!] login FAIL: {exc}")
    sys.exit(1)

# remember
try:
    mem = client.remember(
        "EVO-X3 MCP demo: ANGELICA remembers this test fact.",
        kind="fact",
        layer="working",
        metadata={"evox3_mcp_demo": True},
    )
    print(f"[+] remember OK id={mem.get('id', '?')} {preview(mem)}")
except mod.AngelicaApiError as exc:
    print(f"[!] remember FAIL: {exc}")
    sys.exit(1)

# recall
try:
    rec = client.recall("EVO-X3", memory_limit=5, card_top_k=3)
    nmem = len(rec.get("memories") or [])
    cards = rec.get("cards")
    if isinstance(cards, dict):
        ncard = len(cards.get("results") or [])
    elif isinstance(cards, list):
        ncard = len(cards)
    else:
        ncard = 0
    print(f"[+] recall OK memories={nmem} cards={ncard}")
except mod.AngelicaApiError as exc:
    print(f"[!] recall FAIL: {exc}")
    sys.exit(1)

# connect
try:
    conn = client.connect("EVO-X3", "ANGELICA", relation="HOSTS", description="EVO-X3 hosts ANGELICA kiosk")
    print(f"[+] connect OK id={conn.get('id', '?')}")
except mod.AngelicaApiError as exc:
    print(f"[!] connect FAIL: {exc}")
    sys.exit(1)

# analyze
try:
    summary = client.analyze("summary")
    print(f"[+] analyze/summary OK {preview(summary)}")
except mod.AngelicaApiError as exc:
    print(f"[!] analyze FAIL: {exc}")
    print("[!] hint: run ./scripts/evox3/17_graph_analytics.sh first")
    sys.exit(1)

print("[+] 18_demo_mcp.sh complete")
PY
