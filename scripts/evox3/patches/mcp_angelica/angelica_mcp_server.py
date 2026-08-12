#!/usr/bin/env python3
# EVOX3_MCP_ANGELICA: stdio MCP server exposing ANGELICA remember/recall/connect/analyze.
from __future__ import annotations

import json
import sys
from pathlib import Path

# Allow import when run from Jinhua scripts/ dir.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from angelica_api_client import AngelicaApiError, AngelicaClient

try:
    from mcp.server.fastmcp import FastMCP
except ImportError as exc:  # pragma: no cover
    print(
        "Missing MCP SDK. Install in Jinhua venv: pip install 'mcp>=1.2,<2'",
        file=sys.stderr,
    )
    raise SystemExit(1) from exc

mcp = FastMCP("ANGELICA")
_client = AngelicaClient()


def _json(data: object) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2, default=str)


@mcp.tool()
def remember(content: str, kind: str = "fact", layer: str = "semantic") -> str:
    """Store a stable fact or preference in ANGELICA long-term memory."""
    try:
        item = _client.remember(content, kind=kind, layer=layer)
        return _json({"ok": True, "memory": item})
    except AngelicaApiError as exc:
        return _json({"ok": False, "error": str(exc)})


@mcp.tool()
def recall(query: str = "", memory_limit: int = 20, card_top_k: int = 5) -> str:
    """Recall memories and optionally search indexed cards by natural-language query."""
    try:
        result = _client.recall(query or None, memory_limit=memory_limit, card_top_k=card_top_k)
        return _json({"ok": True, **result})
    except AngelicaApiError as exc:
        return _json({"ok": False, "error": str(exc)})


@mcp.tool()
def connect(source: str, target: str, relation: str = "RELATED_TO", description: str = "") -> str:
    """Record a connection between two concepts as a structured memory fact."""
    try:
        item = _client.connect(
            source,
            target,
            relation=relation,
            description=description or None,
        )
        return _json({"ok": True, "connection": item})
    except AngelicaApiError as exc:
        return _json({"ok": False, "error": str(exc)})


@mcp.tool()
def analyze(
    kind: str = "summary",
    top_n: int = 10,
    source_id: str = "",
    target_id: str = "",
) -> str:
    """Run Neo4j graph analytics (summary, orphans, pagerank, communities, bridges, shortest_path)."""
    try:
        body = _client.analyze(
            kind,
            top_n=top_n,
            source_id=source_id or None,
            target_id=target_id or None,
        )
        return _json({"ok": True, "kind": kind, "result": body})
    except AngelicaApiError as exc:
        return _json({"ok": False, "error": str(exc)})


if __name__ == "__main__":
    mcp.run()
