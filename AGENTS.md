# AGENTS.md

## Cursor Cloud specific instructions

This repository (`thomaspas/thoma`) holds **EVO-X3** runbooks and idempotent scripts. **ANGELICA** is the product name for [GBrain](https://github.com/garrytan/gbrain) Nate **Level 5** on the Mini PC. It is not the runtime host for Docker/LLM/GBrain services.

### What lives here

- [`docs/EVOX3_MACHINE_AND_CHANGES.md`](docs/EVOX3_MACHINE_AND_CHANGES.md) — **source of truth**: Mini PC hardware, how it works, change history
- [`docs/ANGELICA_GBRAIN_LEVEL5.md`](docs/ANGELICA_GBRAIN_LEVEL5.md) — GBrain Level 5 operator runbook
- [`docs/CURSOR_REMOTE_EVOX3.md`](docs/CURSOR_REMOTE_EVOX3.md) — Cursor Desktop Remote SSH + GBrain MCP
- [`docs/REMOTE_OPERATOR_SSH.md`](docs/REMOTE_OPERATOR_SSH.md) — SSH-only operator (Thomas runs from another PC/room)
- [`docs/SESSION_CHRONICLE_ANGELICA.md`](docs/SESSION_CHRONICLE_ANGELICA.md) — saved conversation chronicle
- [`docs/EVOX3_JINHUA_LOCAL_FULL.md`](docs/EVOX3_JINHUA_LOCAL_FULL.md) — **historical** Jinhua kiosk runbook (retired 2026-08-13)
- [`scripts/evox3/`](scripts/evox3/) — steps `01`–`28` + demos (`26` retire Jinhua, `27` GBrain, `28` verify)
- [`extensions/angelica-capture/`](extensions/angelica-capture/) — ANGELICA Capture browser extension (MV3; Jinhua-era)

**Status:** ANGELICA = GBrain Level 5. Jinhua kiosk stack is **off** (disable/archive, not wipe). Keep llama/WebUI/SearXNG.

### Remote operator (Thomas)

- User runs **all commands via SSH** from another machine/room (`thomas-pashoulas@192.168.1.8` — Gaming-7 PC), or Cursor Desktop Remote SSH (`Host evox3`).
- **Never** instruct «go to the EVO-X3 / look at the screen / check the kiosk visually» as a primary step.
- **Always** prefer: `28_gbrain_verify.sh` (current), paste script output. Historical: `21_remote_verify.sh` / `09_smoke_check.sh` for the retired Jinhua stack.
- Remote confirmation is via HTTP/process probes, not physical visit.

### Cloud agent constraints

- There are **no cloud services** to start in this workspace.
- Do **not** expect `package.json` / app runtime under `/workspace`. GBrain workspace on EVO-X3 is `~/gbrain-agent` (not `~/thoma`). The retired Jinhua clone was `~/ai_apps/IncubativeSecondBrain` (archived by `26`).
- Product name is **ANGELICA** (identity files in `~/gbrain-agent`, systemd `angelica-gbrain.service`).
- Cloud agent has **no SSH** to EVO-X3 — user pastes terminal output from their SSH / Cursor Remote session.
- **Never** `npm install -g gbrain` (unrelated npm package). Only `bun install -g github:garrytan/gbrain`.

### How the user runs it (on EVO-X3 via SSH)

```bash
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
./scripts/evox3/26_retire_jinhua_kiosk.sh
./scripts/evox3/27_gbrain_angelica.sh
./scripts/evox3/28_gbrain_verify.sh
```

Ports to keep: `:11434` llama, `:8080` Open WebUI, `:8888` SearXNG. GBrain HTTP admin (always-on unit): `:3131` loopback. Cursor MCP is stdio `gbrain serve`, not that HTTP port.

### Gotchas

- Nested SSH: if already on `thomas-pashoulas-EVO-X3`, do not `ssh 192.168.1.8`.
- After Jinhua retire, reboot Postgres `:5432` / kiosk `:5173` being down is **expected**. Do not re-enable `evox3-jinhua-*` unless Thomas asks for rollback.
- Historical: after reboot, Jinhua login HTTP 500 + `Connection refused` on `:5432` meant docker compose was down (`02` / `evox3-jinhua-docker.service`).
- SSH bracketed paste (`^[[200~`) breaks hand-rolled `TOKEN=` — use demo scripts.
- Do not init GBrain inside `~/thoma`. Do not wipe `~/models` or Docker volumes in the first pass.
- Memory Stargraph and Claude Code `BOOTSTRAP_FOR_AGENTS.md` interview are **out of first pass**. Thomas lives in **Cursor**.

### Lint / test / build (this repo)

- Shell scripts: `bash -n scripts/evox3/*.sh`
- Extension: `./scripts/evox3/19_browser_extension.sh` (no npm; copies MV3 source to `build/`)
- No automated test suite yet for these operator scripts.
