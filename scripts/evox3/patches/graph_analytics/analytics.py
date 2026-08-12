# EVOX3_GRAPH_ANALYTICS: user-scoped Neo4j analytics (stdlib only, no GDS/networkx).
from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Any

from secondbrain.graph.neo4j_client import Neo4jClient, get_neo4j_client


@dataclass
class UserGraph:
    """Undirected multi-edge collapse for analytics (Entity subgraph for one user)."""

    nodes: dict[str, dict[str, Any]]  # id -> {name, type}
    # undirected adjacency: id -> set of neighbor ids
    adj: dict[str, set[str]]
    # undirected edges with a sample relation type: frozenset({a,b}) -> rel_type
    edges: dict[frozenset[str], str]


class GraphAnalyticsUnavailable(Exception):
    """Neo4j disabled or unreachable."""


def _client() -> Neo4jClient:
    return get_neo4j_client()


def require_neo4j() -> Neo4jClient:
    client = _client()
    if not client.enabled:
        raise GraphAnalyticsUnavailable(
            "GRAPH_ENABLED=false — set GRAPH_ENABLED=true in .env and restart API"
        )
    if not client.verify():
        raise GraphAnalyticsUnavailable(
            "Neo4j unreachable on bolt — run ./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh"
        )
    return client


def export_user_graph(user_id: str, client: Neo4jClient | None = None) -> UserGraph:
    client = client or require_neo4j()
    rows = client.run(
        """
        MATCH (e:Entity {user_id: $user_id})
        OPTIONAL MATCH (e)-[r]-(o:Entity {user_id: $user_id})
        RETURN e.id AS id,
               e.name AS name,
               e.type AS type,
               o.id AS other_id,
               type(r) AS rel_type
        """,
        user_id=user_id,
    )
    nodes: dict[str, dict[str, Any]] = {}
    adj: dict[str, set[str]] = defaultdict(set)
    edges: dict[frozenset[str], str] = {}
    for row in rows:
        eid = row.get("id")
        if not eid:
            continue
        nodes[eid] = {
            "name": row.get("name") or eid,
            "type": row.get("type") or "Other",
        }
        other = row.get("other_id")
        if other and other != eid:
            adj[eid].add(other)
            adj[other].add(eid)
            key = frozenset({eid, other})
            if key not in edges:
                edges[key] = row.get("rel_type") or "RELATED_TO"
            nodes.setdefault(
                other,
                {"name": other, "type": "Other"},
            )
    for nid in nodes:
        adj.setdefault(nid, set())
    return UserGraph(nodes=nodes, adj=dict(adj), edges=edges)


def summary(user_id: str) -> dict[str, Any]:
    client = require_neo4j()
    g = export_user_graph(user_id, client)
    orphan_n = len(orphans_from_graph(g))
    return {
        "neo4j_enabled": True,
        "neo4j_reachable": True,
        "entity_count": len(g.nodes),
        "edge_count": len(g.edges),
        "orphan_count": orphan_n,
        "engine": "evox3-stdlib",
    }


def orphans_from_graph(g: UserGraph) -> list[dict[str, Any]]:
    out = []
    for nid, meta in g.nodes.items():
        if not g.adj.get(nid):
            out.append(
                {
                    "id": nid,
                    "name": meta["name"],
                    "entity_type": meta["type"],
                }
            )
    out.sort(key=lambda x: (x["name"], x["id"]))
    return out


def orphans(user_id: str) -> list[dict[str, Any]]:
    return orphans_from_graph(export_user_graph(user_id))


def pagerank(
    user_id: str,
    *,
    top_n: int = 50,
    damping: float = 0.85,
    max_iter: int = 50,
    tol: float = 1e-6,
) -> list[dict[str, Any]]:
    g = export_user_graph(user_id)
    nodes = list(g.nodes.keys())
    n = len(nodes)
    if n == 0:
        return []
    idx = {nid: i for i, nid in enumerate(nodes)}
    scores = [1.0 / n] * n
    out_deg = [max(len(g.adj.get(nid, ())), 1) for nid in nodes]

    for _ in range(max_iter):
        nxt = [(1.0 - damping) / n] * n
        for i, nid in enumerate(nodes):
            if not g.adj.get(nid):
                # dangling: distribute uniformly
                share = damping * scores[i] / n
                for j in range(n):
                    nxt[j] += share
                continue
            share = damping * scores[i] / out_deg[i]
            for nb in g.adj[nid]:
                nxt[idx[nb]] += share
        diff = sum(abs(nxt[i] - scores[i]) for i in range(n))
        scores = nxt
        if diff < tol:
            break

    ranked = sorted(
        (
            {
                "id": nid,
                "name": g.nodes[nid]["name"],
                "entity_type": g.nodes[nid]["type"],
                "score": round(scores[idx[nid]], 8),
            }
            for nid in nodes
        ),
        key=lambda x: (-x["score"], x["name"]),
    )
    return ranked[: max(1, top_n)]


def louvain_communities(user_id: str, *, max_passes: int = 10) -> list[dict[str, Any]]:
    """Simplified Louvain phase-1 (local modularity moves). Fine for small personal graphs."""
    g = export_user_graph(user_id)
    nodes = list(g.nodes.keys())
    if not nodes:
        return []
    m = len(g.edges)
    m2 = float(2 * m) if m else 0.0
    membership = {n: i for i, n in enumerate(nodes)}
    deg = {n: len(g.adj.get(n, ())) for n in nodes}

    def community_total_degree(c: int) -> float:
        return float(sum(deg[n] for n, mc in membership.items() if mc == c))

    def edge_weight_to_comm(n: str, c: int) -> float:
        return float(sum(1 for nb in g.adj.get(n, ()) if membership[nb] == c))

    def delta_to_comm(n: str, c: int, *, excluding_self: bool) -> float:
        if m2 <= 0:
            return 0.0
        k_n = deg[n]
        sigma_tot = community_total_degree(c) - (k_n if excluding_self else 0.0)
        ki_in = edge_weight_to_comm(n, c)
        return (ki_in / m2) - (sigma_tot * k_n) / (m2 * m2)

    for _ in range(max_passes):
        moved = False
        for n in nodes:
            if deg[n] == 0 or m2 <= 0:
                continue
            cur = membership[n]
            cand = {membership[nb] for nb in g.adj.get(n, ())}
            cand.add(cur)
            stay = delta_to_comm(n, cur, excluding_self=True)
            best = cur
            best_delta = stay
            for c in cand:
                if c == cur:
                    continue
                delta = delta_to_comm(n, c, excluding_self=False)
                if delta > best_delta + 1e-12:
                    best_delta = delta
                    best = c
            if best != cur:
                membership[n] = best
                moved = True
        if not moved:
            break

    remap: dict[int, int] = {}
    clusters: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for n, c in membership.items():
        if c not in remap:
            remap[c] = len(remap)
        cid = remap[c]
        clusters[cid].append(
            {
                "id": n,
                "name": g.nodes[n]["name"],
                "entity_type": g.nodes[n]["type"],
            }
        )

    out = []
    for cid in sorted(clusters.keys()):
        members = sorted(clusters[cid], key=lambda x: (x["name"], x["id"]))
        out.append(
            {
                "community_id": cid,
                "size": len(members),
                "members": members,
            }
        )
    out.sort(key=lambda x: (-x["size"], x["community_id"]))
    return out


def bridges(user_id: str) -> list[dict[str, Any]]:
    """Tarjan bridges on undirected graph."""
    g = export_user_graph(user_id)
    tin: dict[str, int] = {}
    low: dict[str, int] = {}
    visited: set[str] = set()
    timer = 0
    found: list[tuple[str, str]] = []

    def dfs(v: str, parent: str | None) -> None:
        nonlocal timer
        visited.add(v)
        tin[v] = low[v] = timer
        timer += 1
        for to in g.adj.get(v, ()):
            if to == parent:
                continue
            if to in visited:
                low[v] = min(low[v], tin[to])
            else:
                dfs(to, v)
                low[v] = min(low[v], low[to])
                if low[to] > tin[v]:
                    a, b = sorted([v, to])
                    found.append((a, b))

    for n in g.nodes:
        if n not in visited:
            dfs(n, None)

    out = []
    for a, b in found:
        key = frozenset({a, b})
        out.append(
            {
                "source_id": a,
                "target_id": b,
                "source_name": g.nodes[a]["name"],
                "target_name": g.nodes[b]["name"],
                "relation_type": g.edges.get(key, "RELATED_TO"),
            }
        )
    out.sort(key=lambda x: (x["source_name"], x["target_name"]))
    return out


def shortest_path(
    user_id: str, *, source_id: str, target_id: str
) -> dict[str, Any]:
    g = export_user_graph(user_id)
    if source_id not in g.nodes or target_id not in g.nodes:
        return {
            "source_id": source_id,
            "target_id": target_id,
            "found": False,
            "length": None,
            "path": [],
            "path_names": [],
        }
    if source_id == target_id:
        return {
            "source_id": source_id,
            "target_id": target_id,
            "found": True,
            "length": 0,
            "path": [source_id],
            "path_names": [g.nodes[source_id]["name"]],
        }
    prev: dict[str, str | None] = {source_id: None}
    q: deque[str] = deque([source_id])
    found = False
    while q:
        v = q.popleft()
        for nb in g.adj.get(v, ()):
            if nb in prev:
                continue
            prev[nb] = v
            if nb == target_id:
                found = True
                q.clear()
                break
            q.append(nb)
    if not found:
        return {
            "source_id": source_id,
            "target_id": target_id,
            "found": False,
            "length": None,
            "path": [],
            "path_names": [],
        }
    path: list[str] = []
    cur: str | None = target_id
    while cur is not None:
        path.append(cur)
        cur = prev[cur]
    path.reverse()
    return {
        "source_id": source_id,
        "target_id": target_id,
        "found": True,
        "length": len(path) - 1,
        "path": path,
        "path_names": [g.nodes[p]["name"] for p in path],
    }
