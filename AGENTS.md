# AGENTS.md

## Cursor Cloud specific instructions

This repository (`thomaspas/thoma`) holds **EVO-X3** runbooks and idempotent scripts. **Jinhua / IncubativeSecondBrain is being fully wiped** (`29_wipe_jinhua.sh`). Keep llama, `~/models`, Open WebUI, SearXNG. Next project is separate (Jarvis). This repo is not the runtime host.

### What lives here

- [`docs/EVOX3_MACHINE_AND_CHANGES.md`](docs/EVOX3_MACHINE_AND_CHANGES.md) — **source of truth**: Mini PC hardware, how it works, change history
- [`docs/JINHUA_FULL_WIPE.md`](docs/JINHUA_FULL_WIPE.md) — **current**: complete Jinhua destroy (what to keep / delete)
- [`docs/ANGELICA_GRAPH_AND_JARVIS.md`](docs/ANGELICA_GRAPH_AND_JARVIS.md) — superseded while Jinhua is wiped (graph dies with Neo4j)
- [`docs/CURSOR_REMOTE_EVOX3.md`](docs/CURSOR_REMOTE_EVOX3.md) — Cursor Desktop Remote SSH + GBrain MCP
- [`docs/REMOTE_OPERATOR_SSH.md`](docs/REMOTE_OPERATOR_SSH.md) — SSH-only operator (Thomas runs from another PC/room)
- [`docs/SESSION_CHRONICLE_ANGELICA.md`](docs/SESSION_CHRONICLE_ANGELICA.md) — saved conversation chronicle
- [`docs/EVOX3_JINHUA_LOCAL_FULL.md`](docs/EVOX3_JINHUA_LOCAL_FULL.md) — Jinhua stack runbook (graph slice still in use)
- [`scripts/evox3/`](scripts/evox3/) — steps `01`–`29` (`29` = full Jinhua wipe)
- [`extensions/angelica-capture/`](extensions/angelica-capture/) — ANGELICA Capture browser extension (MV3; Jinhua-era)

**Status:** Full **Jinhua wipe**. Run `EVOX3_WIPE_JINHUA=YES ./scripts/evox3/29_wipe_jinhua.sh` on EVO-X3. See [`docs/JINHUA_FULL_WIPE.md`](docs/JINHUA_FULL_WIPE.md). Do **not** run `run_all.sh` / `02` after wipe.

### Remote operator (Thomas)

- User runs **all commands via SSH** from another machine/room (`thomas-pashoulas@192.168.1.8` — Gaming-7 PC), or Cursor Desktop Remote SSH (`Host evox3`).
- **Never** instruct «go to the EVO-X3 / look at the screen / check the kiosk visually» as a primary step.
- **Always** prefer: after wipe, paste `29` output. Do **not** re-run Jinhua `02`/`12`/`run_all`.
- Remote confirmation is via HTTP/process probes, not physical visit.

### Cloud agent constraints

- There are **no cloud services** to start in this workspace.
- Do **not** expect `package.json` / app runtime under `/workspace`. After wipe there is no Jinhua clone on EVO-X3.
- Cloud agent has **no SSH** to EVO-X3 — user pastes `29` output from Cursor Remote SSH.
- Full Jinhua destroy: `EVOX3_WIPE_JINHUA=YES ./scripts/evox3/29_wipe_jinhua.sh`. Never wipe `~/models`.
- Do not reinstall Jinhua (`run_all.sh` / `02` / `12`) unless Thomas explicitly asks.

### How the user runs it (on EVO-X3 via SSH)

```bash
cd "$HOME/thoma"
git fetch origin cursor/jinhua-full-wipe-f924
git checkout cursor/jinhua-full-wipe-f924
chmod +x scripts/evox3/*.sh
EVOX3_WIPE_JINHUA=YES ./scripts/evox3/29_wipe_jinhua.sh
```

Keep llama `:11434`, `~/models`, Open WebUI, SearXNG. Jinhua ports/clone/volumes gone.

### Gotchas

- Nested SSH: if already on `thomas-pashoulas-EVO-X3`, do not `ssh 192.168.1.8`.
- `29` requires `EVOX3_WIPE_JINHUA=YES` (destroys Neo4j/Postgres volumes).
- Never delete `~/models` or llama-server as part of Jinhua wipe.

### Lint / test / build (this repo)

- Shell scripts: `bash -n scripts/evox3/*.sh`
- Extension: `./scripts/evox3/19_browser_extension.sh` (no npm; copies MV3 source to `build/`)
- No automated test suite yet for these operator scripts.
