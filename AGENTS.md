# AGENTS.md

## Cursor Cloud specific instructions

This repository (`thomaspas/thoma`) holds **EVO-X3** runbooks and idempotent scripts. **ANGELICA** is the **knowledge graph** (Neo4j + React Flow) from the Second Brain. **Jarvis** is the next assistant. This repo is not the runtime host.

### What lives here

- [`docs/EVOX3_MACHINE_AND_CHANGES.md`](docs/EVOX3_MACHINE_AND_CHANGES.md) — **source of truth**: Mini PC hardware, how it works, change history
- [`docs/ANGELICA_GRAPH_AND_JARVIS.md`](docs/ANGELICA_GRAPH_AND_JARVIS.md) — **current product split**: graph stays, Jarvis is next
- [`docs/CURSOR_REMOTE_EVOX3.md`](docs/CURSOR_REMOTE_EVOX3.md) — Cursor Desktop Remote SSH + GBrain MCP
- [`docs/REMOTE_OPERATOR_SSH.md`](docs/REMOTE_OPERATOR_SSH.md) — SSH-only operator (Thomas runs from another PC/room)
- [`docs/SESSION_CHRONICLE_ANGELICA.md`](docs/SESSION_CHRONICLE_ANGELICA.md) — saved conversation chronicle
- [`docs/EVOX3_JINHUA_LOCAL_FULL.md`](docs/EVOX3_JINHUA_LOCAL_FULL.md) — Jinhua stack runbook (graph slice still in use)
- [`scripts/evox3/`](scripts/evox3/) — steps `01`–`28` + demos (`26` retire Jinhua, `27` GBrain, `28` verify)
- [`extensions/angelica-capture/`](extensions/angelica-capture/) — ANGELICA Capture browser extension (MV3; Jinhua-era)

**Status:** **ANGELICA = knowledge graph only** (Neo4j + React Flow). Next project: **Jarvis** (separate assistant). Do **not** run `26` (it refuses while `EVOX3_KEEP_GRAPH=1`). See [`docs/ANGELICA_GRAPH_AND_JARVIS.md`](docs/ANGELICA_GRAPH_AND_JARVIS.md).

### Remote operator (Thomas)

- User runs **all commands via SSH** from another machine/room (`thomas-pashoulas@192.168.1.8` — Gaming-7 PC), or Cursor Desktop Remote SSH (`Host evox3`).
- **Never** instruct «go to the EVO-X3 / look at the screen / check the kiosk visually» as a primary step.
- **Always** prefer: keep Neo4j/Graph alive; paste `systemctl --user is-active` + Graph HTTP. Do **not** instruct `26` unless Thomas sets `EVOX3_KEEP_GRAPH=0`. Historical GBrain: `28_gbrain_verify.sh`. Historical kiosk: `21_remote_verify.sh`.
- Remote confirmation is via HTTP/process probes, not physical visit.

### Cloud agent constraints

- There are **no cloud services** to start in this workspace.
- Do **not** expect `package.json` / app runtime under `/workspace`. Graph runtime on EVO-X3: `~/ai_apps/IncubativeSecondBrain` + Docker Neo4j. Do not archive that clone.
- Product name **ANGELICA** = Graph tab / Neo4j, not the full kiosk chat.
- Cloud agent has **no SSH** to EVO-X3 — user pastes terminal output from Cursor Remote SSH.
- **Never** `npm install -g gbrain`. Do not run `26` while `EVOX3_KEEP_GRAPH=1`.

### How the user runs it (on EVO-X3 via SSH)

```bash
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
systemctl --user is-active evox3-jinhua-docker.service evox3-jinhua-api.service evox3-jinhua-web.service
```

Keep Neo4j `:7687`, Graph UI `:5173`, llama `:11434`. Jarvis is not in this repo yet — need the project URL. **Do not** run `26`/`27`/`28` as the default path.

### Gotchas

- Nested SSH: if already on `thomas-pashoulas-EVO-X3`, do not `ssh 192.168.1.8`.
- `26` exits 1 while `EVOX3_KEEP_GRAPH=1` (default) — that protects Neo4j.
- Historical: after reboot, Jinhua login HTTP 500 + `Connection refused` on `:5432` meant docker compose was down (`02`).
- SSH bracketed paste (`^[[200~`) breaks hand-rolled `TOKEN=` — use demo scripts.
- Do not init GBrain inside `~/thoma`. Do not wipe `~/models` or Docker volumes in the first pass.
- Memory Stargraph and Claude Code `BOOTSTRAP_FOR_AGENTS.md` interview are **out of first pass**. Thomas lives in **Cursor**.

### Lint / test / build (this repo)

- Shell scripts: `bash -n scripts/evox3/*.sh`
- Extension: `./scripts/evox3/19_browser_extension.sh` (no npm; copies MV3 source to `build/`)
- No automated test suite yet for these operator scripts.
