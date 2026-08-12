#!/usr/bin/env bash
# Demo Neo4j graph analytics endpoints without fragile shell TOKEN paste.
# Avoids bracketed-paste (^[[200~) breaking export/TOKEN= assignments.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3

API="http://${EVOX3_API_HOST}:${EVOX3_API_PORT}"
EMAIL="${EVOX3_LOCAL_EMAIL}"
PASSWORD="${EVOX3_LOCAL_PASSWORD}"

# Disable bracketed paste for this shell if the terminal supports it.
printf '\e[?2004l' 2>/dev/null || true

python3 - "$API" "$EMAIL" "$PASSWORD" <<'PY'
import json
import sys
import urllib.error
import urllib.request

api, email, password = sys.argv[1], sys.argv[2], sys.argv[3]


def http_json(method: str, url: str, *, data=None, headers=None):
    body = None if data is None else json.dumps(data).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers=headers or {},
        method=method,
    )
    if body is not None and "Content-Type" not in (headers or {}):
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode()
        return resp.status, (json.loads(raw) if raw else None)


try:
    code, login = http_json(
        "POST",
        f"{api}/auth/login",
        data={"email": email, "password": password},
    )
except urllib.error.HTTPError as exc:
    print(f"LOGIN_FAIL HTTP {exc.code}: {exc.read().decode()[:300]}", file=sys.stderr)
    sys.exit(1)
except Exception as exc:  # noqa: BLE001
    print(f"LOGIN_FAIL: {exc}", file=sys.stderr)
    sys.exit(1)

token = (login or {}).get("access_token") or ""
if not token:
    print("LOGIN_FAIL: no access_token", file=sys.stderr)
    sys.exit(1)
print(f"[+] login OK ({email}) token_len={len(token)}")

auth = {"Authorization": f"Bearer {token}"}
paths = [
    "/graph/analytics/summary",
    "/graph/analytics/orphans",
    "/graph/analytics/pagerank?top_n=10",
    "/graph/analytics/communities",
    "/graph/analytics/bridges",
]
for path in paths:
    url = f"{api}{path}"
    try:
        code, payload = http_json("GET", url, headers=auth)
    except urllib.error.HTTPError as exc:
        print(f"[!] {path} HTTP {exc.code}: {exc.read().decode()[:240]}")
        continue
    except Exception as exc:  # noqa: BLE001
        print(f"[!] {path} error: {exc}")
        continue
    # compact preview
    if isinstance(payload, list):
        preview = f"list_len={len(payload)}"
        if payload:
            preview += " first=" + json.dumps(payload[0], ensure_ascii=False)[:160]
    elif isinstance(payload, dict):
        preview = json.dumps(payload, ensure_ascii=False)[:240]
    else:
        preview = str(payload)[:240]
    print(f"[+] {path} HTTP {code}  {preview}")

print("[+] 17_demo_analytics.sh complete")
PY
