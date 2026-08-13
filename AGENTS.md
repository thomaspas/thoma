# AGENTS.md

## Cursor Cloud specific instructions

This repository (`thomaspas/thoma`) holds **EVO-X3 LOCAL FULL** runbooks and idempotent scripts for deploying [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain) on the user's machine as **ANGELICA**. It is not the runtime host for Docker/LLM services.

### What lives here

- [`docs/EVOX3_JINHUA_LOCAL_FULL.md`](docs/EVOX3_JINHUA_LOCAL_FULL.md) — operator runbook
- [`docs/REMOTE_OPERATOR_SSH.md`](docs/REMOTE_OPERATOR_SSH.md) — **SSH-only operator** (Thomas runs from another PC/room)
- [`docs/CURSOR_REMOTE_SSH.md`](docs/CURSOR_REMOTE_SSH.md) — Cursor Desktop Remote SSH + live UI + GNOME RDP
- [`docs/SESSION_CHRONICLE_ANGELICA.md`](docs/SESSION_CHRONICLE_ANGELICA.md) — saved conversation chronicle (DONE LOCAL FULL / ANGELICA + NEXT roadmap)
- [`docs/ANGELICA_BROWSER_EXTENSION.md`](docs/ANGELICA_BROWSER_EXTENSION.md) — MV3 capture extension guide
- [`scripts/evox3/`](scripts/evox3/) — steps `01`–`26` + demos + `run_all.sh` + `bge_m3_server.py`
- [`extensions/angelica-capture/`](extensions/angelica-capture/) — ANGELICA Capture browser extension (MV3, no npm build)

**Status:** LOCAL FULL + ANGELICA + graph analytics + MCP + browser extension + React Flow Graph **DONE** on EVO-X3. Operator live view: Cursor Desktop Remote SSH + GNOME RDP (`25`/`26`). Next: chronicle NEXT #7.

### Remote operator (Thomas)

- User runs **all commands via SSH** from another machine/room (Gaming-7 → `thomas-pashoulas@192.168.1.8` on EVO-X3).
- **Never** instruct «go to the EVO-X3 / look at the screen / check the kiosk visually» as a primary step.
- **Always** prefer: `21_remote_verify.sh`, `09_smoke_check.sh`, `13_remote_go_live.sh`, paste script output (cloud) **or** Cursor Desktop Remote SSH Agent (reads EVO terminal directly).
- Kiosk runs on the EVO-X3 display automatically. Remote confirmation: HTTP/process probes (`21`). Live pixels: GNOME RDP (`26`) or snapshot (`25`) — see [`docs/CURSOR_REMOTE_SSH.md`](docs/CURSOR_REMOTE_SSH.md).
- Cloud Agent chat is **not** the EVO Agent. Live Agent = Cursor Desktop → Remote-SSH: Connect to Host → `evo-x3` → **new** Agent chat in that window.

### Cloud agent constraints

- There are **no cloud services** to start in this workspace.
- Do **not** expect `package.json` / app runtime under `/workspace` for the Second Brain itself; the Jinhua clone lives on EVO-X3 at `~/ai_apps/IncubativeSecondBrain`.
- Extension source lives in `extensions/`; app patches in `scripts/evox3/patches/`.
- Product name on the kiosk is **ANGELICA** (`16_brand_angelica.sh`).
- Cloud agent has **no SSH** to EVO-X3 — user pastes terminal output from their SSH session, **or** uses Cursor Desktop Remote SSH (not this cloud VM).

### How the user runs it (on EVO-X3 via SSH)

```bash
chmod +x scripts/evox3/*.sh
./scripts/evox3/21_remote_verify.sh
```

Smoke checks and ports are documented in the runbook (`:11434` LLM, `:8002` bge-m3, `:8000` API, `:5173` UI, Docker Postgres `:5432` / Neo4j `:7687`).

### Gotchas

- After reboot, login HTTP 500 with `Connection refused` on `:5432` means Docker compose (Postgres) did not come up. Run `02_ensure_jinhua_clone_and_docker.sh` (installs `evox3-jinhua-docker.service`). API docs can still be 200 while DB is down.
- Brand patches live on the EVO-X3 clone (`*.evox3-brand-orig`); re-run `16` after upstream web updates.
- Browser extension uses a **separate** Chromium profile (Load unpacked), not the kiosk.
- SSH bracketed paste (`^[[200~`) breaks hand-rolled `TOKEN=` — use `17_demo` / `18_demo` / `13` scripts.
- Live view is Desktop Remote SSH + GNOME RDP (`docs/CURSOR_REMOTE_SSH.md`); this cloud VM cannot open `192.168.1.8`.

### Lint / test / build (this repo)

- Shell scripts: `bash -n scripts/evox3/*.sh`
- Extension: `./scripts/evox3/19_browser_extension.sh` (no npm; copies MV3 source to `build/`)
- No automated test suite yet for these operator scripts.
