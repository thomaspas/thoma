# EVOX3_GRAPH_ANALYTICS: schemas for Neo4j analytics endpoints.
from __future__ import annotations

from pydantic import BaseModel


class EntityResponse(BaseModel):
    id: str
    canonical_name: str
    entity_type: str
    aliases: list[str]
    source_card_ids: list[str]
    confidence: float

    class Config:
        from_attributes = True


class RelationResponse(BaseModel):
    id: str
    source_entity_id: str
    target_entity_id: str
    relation_type: str
    description: str | None
    evidence_card_id: str | None
    confidence: float

    class Config:
        from_attributes = True


class GraphOverviewResponse(BaseModel):
    entity_count: int
    relation_count: int
    entities: list[EntityResponse]
    relations: list[RelationResponse]


class GraphEntityRef(BaseModel):
    id: str
    name: str
    entity_type: str


class GraphAnalyticsSummaryResponse(BaseModel):
    neo4j_enabled: bool
    neo4j_reachable: bool
    entity_count: int
    edge_count: int
    orphan_count: int
    engine: str


class GraphPageRankItem(BaseModel):
    id: str
    name: str
    entity_type: str
    score: float


class GraphCommunityResponse(BaseModel):
    community_id: int
    size: int
    members: list[GraphEntityRef]


class GraphBridgeResponse(BaseModel):
    source_id: str
    target_id: str
    source_name: str
    target_name: str
    relation_type: str


class GraphShortestPathResponse(BaseModel):
    source_id: str
    target_id: str
    found: bool
    length: int | None
    path: list[str]
    path_names: list[str]
