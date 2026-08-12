# EVOX3_MCP_ANGELICA: REST client for ANGELICA MCP tools (stdlib urllib).
from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


class AngelicaApiError(Exception):
    """ANGELICA API call failed."""


class AngelicaClient:
    def __init__(
        self,
        api_url: str | None = None,
        email: str | None = None,
        password: str | None = None,
    ) -> None:
        self.api_url = (api_url or os.environ.get("ANGELICA_API_URL") or "http://127.0.0.1:8000").rstrip("/")
        self.email = email or os.environ.get("ANGELICA_EMAIL") or "ye@evox3.local"
        self.password = password or os.environ.get("ANGELICA_PASSWORD") or "evox3-local-12"
        self._token: str | None = None

    def login(self) -> str:
        status, body = self._http(
            "POST",
            "/auth/login",
            data={"email": self.email, "password": self.password},
            auth=False,
        )
        if status != 200 or not isinstance(body, dict):
            raise AngelicaApiError(f"login failed HTTP {status}: {body}")
        token = body.get("access_token") or ""
        if not token:
            raise AngelicaApiError("login response missing access_token")
        self._token = token
        return token

    def _auth_headers(self) -> dict[str, str]:
        if not self._token:
            self.login()
        assert self._token
        return {"Authorization": f"Bearer {self._token}"}

    def _http(
        self,
        method: str,
        path: str,
        *,
        data: dict | None = None,
        auth: bool = True,
        retry_on_401: bool = True,
    ) -> tuple[int, Any]:
        url = f"{self.api_url}{path}"
        headers: dict[str, str] = {}
        if auth:
            headers.update(self._auth_headers())
        body_bytes = None if data is None else json.dumps(data).encode()
        if body_bytes is not None:
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=body_bytes, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read().decode()
                payload = json.loads(raw) if raw else None
                return resp.status, payload
        except urllib.error.HTTPError as exc:
            if exc.code == 401 and auth and retry_on_401:
                self._token = None
                self.login()
                return self._http(method, path, data=data, auth=auth, retry_on_401=False)
            detail = exc.read().decode()[:500]
            try:
                parsed = json.loads(detail)
            except json.JSONDecodeError:
                parsed = detail
            return exc.code, parsed

    def remember(
        self,
        content: str,
        *,
        kind: str = "fact",
        layer: str = "semantic",
        importance: float = 1.0,
        metadata: dict | None = None,
    ) -> dict[str, Any]:
        status, body = self._http(
            "POST",
            "/memory",
            data={
                "content": content,
                "kind": kind,
                "layer": layer,
                "importance": importance,
                "metadata": metadata or {},
            },
        )
        if status not in (200, 201):
            raise AngelicaApiError(f"remember failed HTTP {status}: {body}")
        return body if isinstance(body, dict) else {"result": body}

    def recall(
        self,
        query: str | None = None,
        *,
        memory_limit: int = 20,
        card_top_k: int = 5,
    ) -> dict[str, Any]:
        mem_path = f"/memory?limit={max(1, min(memory_limit, 500))}"
        status, memories = self._http("GET", mem_path)
        if status != 200:
            raise AngelicaApiError(f"recall memories failed HTTP {status}: {memories}")
        cards: Any = []
        if query and query.strip():
            q = urllib.parse.quote(query.strip())
            cstatus, cards = self._http(
                "GET",
                f"/cards/search?q={q}&top_k={max(1, min(card_top_k, 50))}",
            )
            if cstatus != 200:
                cards = {"error": cards, "http_status": cstatus}
        return {
            "query": query or "",
            "memories": memories if isinstance(memories, list) else [],
            "cards": cards,
        }

    def connect(
        self,
        source: str,
        target: str,
        *,
        relation: str = "RELATED_TO",
        description: str | None = None,
    ) -> dict[str, Any]:
        statement = description or f"{source} {relation} {target}"
        return self.remember(
            statement,
            kind="fact",
            layer="semantic",
            metadata={
                "evox3_connection": True,
                "source": source,
                "target": target,
                "relation": relation,
            },
        )

    def analyze(
        self,
        kind: str = "summary",
        *,
        top_n: int = 10,
        source_id: str | None = None,
        target_id: str | None = None,
    ) -> Any:
        kind = (kind or "summary").strip().lower()
        if kind == "summary":
            path = "/graph/analytics/summary"
        elif kind == "orphans":
            path = "/graph/analytics/orphans"
        elif kind == "pagerank":
            path = f"/graph/analytics/pagerank?top_n={max(1, min(top_n, 500))}"
        elif kind == "communities":
            path = "/graph/analytics/communities"
        elif kind == "bridges":
            path = "/graph/analytics/bridges"
        elif kind == "shortest_path":
            if not source_id or not target_id:
                raise AngelicaApiError("shortest_path requires source_id and target_id")
            q = urllib.parse.urlencode({"source_id": source_id, "target_id": target_id})
            path = f"/graph/analytics/shortest-path?{q}"
        else:
            raise AngelicaApiError(
                f"unknown analyze kind {kind!r}; use summary|orphans|pagerank|communities|bridges|shortest_path"
            )
        status, body = self._http("GET", path)
        if status == 503:
            raise AngelicaApiError(
                "graph analytics unavailable — run ./scripts/evox3/17_graph_analytics.sh on EVO-X3"
            )
        if status != 200:
            raise AngelicaApiError(f"analyze/{kind} failed HTTP {status}: {body}")
        return body
