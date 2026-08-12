# HANDOFF — React Flow Graph UI

**BLUF:** Full-bleed **Graph** nav (React Flow / `@xyflow/react`) is live on EVO-X3 ANGELICA. Overview 3D panel unchanged. Fable LLM unchanged. **v3** = analytics styling + rich relation colors + enter/growth animations.

## Re-verify one-liner (EVO-X3)

```bash
export PATH="$HOME/.nvm/versions/node/v20.20.2/bin:$PATH" && cd ~/thoma && ./scripts/evox3/21_remote_verify.sh
```

## Apply / refresh (EVO-X3)

```bash
export PATH="$HOME/.nvm/versions/node/v20.20.2/bin:$PATH" && cd ~/thoma && ./scripts/evox3/24_graph_ui_reactflow.sh && ./scripts/evox3/10_relaunch_kiosk.sh && ./scripts/evox3/21_remote_verify.sh
```

**UI:** kiosk sidebar → **Graph** (fullscreen canvas; Fit / Refresh; node drawer).

## Files (`thoma`)

| Path | Role |
|------|------|
| `scripts/evox3/24_graph_ui_reactflow.sh` | Idempotent install + wire App/Sidebar + npm |
| `scripts/evox3/patches/graph_ui/GraphFlowWorkspace.tsx` | React Flow workspace |
| `scripts/evox3/patches/graph_ui/graph_flow.css` | Full-bleed styles |
| Marker | `apps/web/.evox3-graph-ui-reactflow` |

## Sync Gaming-7 → EVO

```bash
rsync -av -e 'ssh -i ~/.ssh/id_ed25519_evox3 -o IdentitiesOnly=yes' ~/thoma/scripts/evox3/24_graph_ui_reactflow.sh ~/thoma/scripts/evox3/09_smoke_check.sh thomas-pashoulas@192.168.1.8:~/thoma/scripts/evox3/ && rsync -av -e 'ssh -i ~/.ssh/id_ed25519_evox3 -o IdentitiesOnly=yes' ~/thoma/scripts/evox3/patches/graph_ui/ thomas-pashoulas@192.168.1.8:~/thoma/scripts/evox3/patches/graph_ui/
```

## Constraints

- No Warden/NEBULA
- Do not change `LLM_MODEL` / Fable GGUF
- Operator: SSH only; Graph tab is the visual check (no physical visit required for verify scripts)
- Chronicle NEXT #4: [`SESSION_CHRONICLE_ANGELICA.md`](SESSION_CHRONICLE_ANGELICA.md)
