/**
 * EVOX3_GRAPH_UI — full-bleed React Flow knowledge graph for ANGELICA kiosk.
 * Installed by scripts/evox3/24_graph_ui_reactflow.sh into apps/web/src/features/graph/.
 */
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type MouseEvent,
} from "react";
import {
  Background,
  BackgroundVariant,
  Controls,
  Handle,
  MarkerType,
  MiniMap,
  Position,
  ReactFlow,
  ReactFlowProvider,
  useEdgesState,
  useNodesState,
  useReactFlow,
  type Edge,
  type Node,
  type NodeProps,
} from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { api, ApiError } from "../../lib/api";
import type { EntityResponse, GraphOverview, RelationResponse } from "../../lib/types";

interface Props {
  reloadSignal: number;
}

type EntityNodeData = {
  label: string;
  entityType: string;
  confidence: number;
};

const TYPE_COLORS: Record<string, string> = {
  person: "#5be0ff",
  organization: "#57e0c0",
  concept: "#ffc24b",
  document: "#aab9dc",
  default: "#7ee7ff",
};

function colorForType(entityType: string): string {
  const key = (entityType || "").toLowerCase();
  return TYPE_COLORS[key] ?? TYPE_COLORS.default;
}

function layoutNodes(entities: EntityResponse[]): Node<EntityNodeData>[] {
  const n = entities.length;
  if (n === 0) return [];
  if (n === 1) {
    const e = entities[0];
    return [
      {
        id: e.id,
        type: "entity",
        position: { x: 0, y: 0 },
        data: {
          label: e.canonical_name,
          entityType: e.entity_type,
          confidence: e.confidence,
        },
      },
    ];
  }
  const radius = Math.max(180, n * 36);
  return entities.map((e, i) => {
    const angle = (2 * Math.PI * i) / n - Math.PI / 2;
    return {
      id: e.id,
      type: "entity",
      position: {
        x: Math.cos(angle) * radius,
        y: Math.sin(angle) * radius,
      },
      data: {
        label: e.canonical_name,
        entityType: e.entity_type,
        confidence: e.confidence,
      },
    };
  });
}

function buildEdges(relations: RelationResponse[]): Edge[] {
  return relations.map((r) => ({
    id: r.id,
    source: r.source_entity_id,
    target: r.target_entity_id,
    label: r.relation_type,
    type: "default",
    animated: false,
    style: { stroke: "rgba(91, 224, 255, 0.45)", strokeWidth: 1.5 },
    labelStyle: {
      fill: "#aab9dc",
      fontSize: 11,
      fontWeight: 500,
    },
    labelBgStyle: { fill: "#0b1326", fillOpacity: 0.9 },
    labelBgPadding: [4, 6] as [number, number],
    markerEnd: {
      type: MarkerType.ArrowClosed,
      width: 16,
      height: 16,
      color: "rgba(91, 224, 255, 0.7)",
    },
  }));
}

function EntityFlowNode({ data, selected }: NodeProps<Node<EntityNodeData>>) {
  const accent = colorForType(data.entityType);
  return (
    <div
      className={`gf-node${selected ? " selected" : ""}`}
      style={{ borderColor: accent, boxShadow: selected ? `0 0 0 1px ${accent}` : undefined }}
    >
      <Handle type="target" position={Position.Left} className="gf-handle" />
      <div className="gf-node-type" style={{ color: accent }}>
        {data.entityType || "entity"}
      </div>
      <div className="gf-node-label">{data.label}</div>
      <Handle type="source" position={Position.Right} className="gf-handle" />
    </div>
  );
}

const nodeTypes = { entity: EntityFlowNode };

function GraphFlowCanvas({ reloadSignal }: Props) {
  const [data, setData] = useState<GraphOverview | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [loaded, setLoaded] = useState(false);
  const [selected, setSelected] = useState<EntityResponse | null>(null);
  const [nodes, setNodes, onNodesChange] = useNodesState<Node<EntityNodeData>>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);
  const { fitView } = useReactFlow();

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const overview = await api.graphOverview(300);
      setData(overview);
      setNodes(layoutNodes(overview.entities));
      setEdges(buildEdges(overview.relations));
      setLoaded(true);
      setSelected(null);
      requestAnimationFrame(() => {
        fitView({ padding: 0.22, duration: 280 });
      });
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Load failed");
    } finally {
      setLoading(false);
    }
  }, [fitView, setEdges, setNodes]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    if (reloadSignal > 0) load();
  }, [reloadSignal, load]);

  const onNodeClick = useCallback(
    (_: MouseEvent, node: Node) => {
      const ent = data?.entities.find((e) => e.id === node.id) ?? null;
      setSelected(ent);
    },
    [data]
  );

  const onPaneClick = useCallback(() => setSelected(null), []);

  const sparse = useMemo(() => {
    if (!data) return false;
    return data.entities.length > 0 && data.entities.length < 4;
  }, [data]);

  const empty = loaded && data && data.entities.length === 0;

  return (
    <section className="graph-flow-workspace" data-evox3="graph-ui">
      <header className="graph-flow-toolbar">
        <div className="graph-flow-toolbar-left">
          <h2 className="graph-flow-title">Graph</h2>
          <span className="graph-flow-meta muted sm">
            {loaded && data
              ? `${data.entity_count} entities · ${data.relation_count} relations`
              : loading
                ? "Loading…"
                : "—"}
          </span>
        </div>
        <div className="graph-flow-toolbar-actions">
          <button
            type="button"
            className="btn ghost sm"
            onClick={() => fitView({ padding: 0.22, duration: 280 })}
            disabled={!loaded || !!empty}
          >
            Fit
          </button>
          <button type="button" className="btn ghost sm" onClick={load} disabled={loading}>
            Refresh
          </button>
        </div>
      </header>

      {error && <div className="notice err sm graph-flow-error">{error}</div>}

      <div className="graph-flow-body">
        <div className="graph-flow-canvas-wrap">
          {empty && (
            <div className="graph-flow-empty">
              <p className="graph-flow-empty-title">No graph data yet</p>
              <p className="muted sm">
                Ingest documents from Knowledge Base to populate entities and relations.
              </p>
            </div>
          )}
          {sparse && !empty && (
            <div className="graph-flow-sparse" role="status">
              Sparse graph — ingest more notes to grow the map.
            </div>
          )}
          {!loaded && loading && (
            <div className="graph-flow-empty">
              <p className="muted sm">Loading graph…</p>
            </div>
          )}
          <ReactFlow
            nodes={nodes}
            edges={edges}
            onNodesChange={onNodesChange}
            onEdgesChange={onEdgesChange}
            onNodeClick={onNodeClick}
            onPaneClick={onPaneClick}
            nodeTypes={nodeTypes}
            fitView
            fitViewOptions={{ padding: 0.22 }}
            minZoom={0.2}
            maxZoom={2.5}
            proOptions={{ hideAttribution: true }}
            colorMode="dark"
          >
            <Background
              variant={BackgroundVariant.Dots}
              gap={22}
              size={1.2}
              color="rgba(91, 224, 255, 0.12)"
            />
            <Controls showInteractive={false} className="graph-flow-controls" />
            <MiniMap
              className="graph-flow-minimap"
              nodeColor={(n) => colorForType(String((n.data as EntityNodeData)?.entityType || ""))}
              maskColor="rgba(7, 11, 22, 0.75)"
              pannable
              zoomable
            />
          </ReactFlow>
        </div>

        {selected && (
          <aside className="graph-flow-drawer" aria-label="Entity details">
            <div className="graph-flow-drawer-head">
              <h3>{selected.canonical_name}</h3>
              <button type="button" className="btn ghost sm" onClick={() => setSelected(null)}>
                Close
              </button>
            </div>
            <dl className="graph-flow-drawer-body">
              <div>
                <dt>Type</dt>
                <dd style={{ color: colorForType(selected.entity_type) }}>{selected.entity_type}</dd>
              </div>
              <div>
                <dt>Confidence</dt>
                <dd>{Math.round((selected.confidence ?? 0) * 100)}%</dd>
              </div>
              {selected.aliases?.length > 0 && (
                <div>
                  <dt>Aliases</dt>
                  <dd>{selected.aliases.join(", ")}</dd>
                </div>
              )}
              <div>
                <dt>Source cards</dt>
                <dd>{selected.source_card_ids?.length ?? 0}</dd>
              </div>
            </dl>
            {data && (
              <div className="graph-flow-drawer-rels">
                <div className="dash-block-title">Relations</div>
                <ul>
                  {data.relations
                    .filter(
                      (r) =>
                        r.source_entity_id === selected.id || r.target_entity_id === selected.id
                    )
                    .slice(0, 24)
                    .map((r) => {
                      const otherId =
                        r.source_entity_id === selected.id
                          ? r.target_entity_id
                          : r.source_entity_id;
                      const other = data.entities.find((e) => e.id === otherId);
                      const outbound = r.source_entity_id === selected.id;
                      return (
                        <li key={r.id}>
                          <span className="muted">{outbound ? "→" : "←"}</span>{" "}
                          <span className="graph-flow-rel-type">{r.relation_type}</span>{" "}
                          {other?.canonical_name ?? otherId}
                        </li>
                      );
                    })}
                </ul>
              </div>
            )}
          </aside>
        )}
      </div>
    </section>
  );
}

export default function GraphFlowWorkspace({ reloadSignal }: Props) {
  return (
    <ReactFlowProvider>
      <GraphFlowCanvas reloadSignal={reloadSignal} />
    </ReactFlowProvider>
  );
}
