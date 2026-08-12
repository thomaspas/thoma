# EVOX3_GRAPH_ANALYTICS: Postgres mirror routes + Neo4j analytics.
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from apps.api.dependencies import get_current_user_id, get_db
from apps.api.schemas.graph import (
    EntityResponse,
    GraphAnalyticsSummaryResponse,
    GraphBridgeResponse,
    GraphCommunityResponse,
    GraphEntityRef,
    GraphOverviewResponse,
    GraphPageRankItem,
    GraphShortestPathResponse,
    RelationResponse,
)
from secondbrain.db.repositories import graph_mirror
from secondbrain.graph import analytics as graph_analytics

router = APIRouter(prefix="/graph", tags=["graph"])


def _unavailable(exc: graph_analytics.GraphAnalyticsUnavailable) -> HTTPException:
    return HTTPException(
        status_code=503,
        detail=str(exc),
    )


@router.get("/entities", response_model=list[EntityResponse])
def list_entities(
    limit: int = Query(default=200, ge=1, le=1000),
    session: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> list[EntityResponse]:
    return graph_mirror.list_entities(session, user_id, limit=limit)


@router.get("/relations", response_model=list[RelationResponse])
def list_relations(
    limit: int = Query(default=200, ge=1, le=1000),
    session: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> list[RelationResponse]:
    return graph_mirror.list_relations(session, user_id, limit=limit)


@router.get("/overview", response_model=GraphOverviewResponse)
def overview(
    limit: int = Query(default=200, ge=1, le=1000),
    session: Session = Depends(get_db),
    user_id: str = Depends(get_current_user_id),
) -> GraphOverviewResponse:
    entities = graph_mirror.list_entities(session, user_id, limit=limit)
    relations = graph_mirror.list_relations(session, user_id, limit=limit)
    return GraphOverviewResponse(
        entity_count=len(entities),
        relation_count=len(relations),
        entities=entities,
        relations=relations,
    )


@router.get("/analytics/summary", response_model=GraphAnalyticsSummaryResponse)
def analytics_summary(
    user_id: str = Depends(get_current_user_id),
) -> GraphAnalyticsSummaryResponse:
    try:
        return GraphAnalyticsSummaryResponse(**graph_analytics.summary(user_id))
    except graph_analytics.GraphAnalyticsUnavailable as exc:
        raise _unavailable(exc) from exc


@router.get("/analytics/orphans", response_model=list[GraphEntityRef])
def analytics_orphans(
    user_id: str = Depends(get_current_user_id),
) -> list[GraphEntityRef]:
    try:
        rows = graph_analytics.orphans(user_id)
    except graph_analytics.GraphAnalyticsUnavailable as exc:
        raise _unavailable(exc) from exc
    return [GraphEntityRef(**r) for r in rows]


@router.get("/analytics/pagerank", response_model=list[GraphPageRankItem])
def analytics_pagerank(
    top_n: int = Query(default=50, ge=1, le=500),
    user_id: str = Depends(get_current_user_id),
) -> list[GraphPageRankItem]:
    try:
        rows = graph_analytics.pagerank(user_id, top_n=top_n)
    except graph_analytics.GraphAnalyticsUnavailable as exc:
        raise _unavailable(exc) from exc
    return [GraphPageRankItem(**r) for r in rows]


@router.get("/analytics/communities", response_model=list[GraphCommunityResponse])
def analytics_communities(
    user_id: str = Depends(get_current_user_id),
) -> list[GraphCommunityResponse]:
    try:
        rows = graph_analytics.louvain_communities(user_id)
    except graph_analytics.GraphAnalyticsUnavailable as exc:
        raise _unavailable(exc) from exc
    return [
        GraphCommunityResponse(
            community_id=r["community_id"],
            size=r["size"],
            members=[GraphEntityRef(**m) for m in r["members"]],
        )
        for r in rows
    ]


@router.get("/analytics/bridges", response_model=list[GraphBridgeResponse])
def analytics_bridges(
    user_id: str = Depends(get_current_user_id),
) -> list[GraphBridgeResponse]:
    try:
        rows = graph_analytics.bridges(user_id)
    except graph_analytics.GraphAnalyticsUnavailable as exc:
        raise _unavailable(exc) from exc
    return [GraphBridgeResponse(**r) for r in rows]


@router.get("/analytics/shortest-path", response_model=GraphShortestPathResponse)
def analytics_shortest_path(
    source_id: str = Query(..., min_length=1),
    target_id: str = Query(..., min_length=1),
    user_id: str = Depends(get_current_user_id),
) -> GraphShortestPathResponse:
    try:
        row = graph_analytics.shortest_path(
            user_id, source_id=source_id, target_id=target_id
        )
    except graph_analytics.GraphAnalyticsUnavailable as exc:
        raise _unavailable(exc) from exc
    return GraphShortestPathResponse(**row)
