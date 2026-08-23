# AGENTS.md

## Cursor Cloud specific instructions

This repository (`thomaspas/thoma`) holds **EVO-X3 LOCAL FULL** runbooks and idempotent scripts for deploying [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain) on the user's machine as **ANGELICA**. It is not the runtime host for Docker/LLM services.

### What lives here

- [`docs/EVOX3_JINHUA_LOCAL_FULL.md`](docs/EVOX3_JINHUA_LOCAL_FULL.md) — operator runbook
- [`docs/REMOTE_OPERATOR_SSH.md`](docs/REMOTE_OPERATOR_SSH.md) — **SSH-only operator** (Thomas runs from another PC/room)
- [`docs/CURSOR_REMOTE_EVOX3.md`](docs/CURSOR_REMOTE_EVOX3.md) — Cursor Desktop Remote-SSH to EVO (cloud has no LAN)
- [`docs/OPERATOR_RECOVER_NOW.md`](docs/OPERATOR_RECOVER_NOW.md) — one-page recover card (wipe / bge timeout / missing units)
- [`docs/SESSION_CHRONICLE_ANGELICA.md`](docs/SESSION_CHRONICLE_ANGELICA.md) — saved conversation chronicle (DONE LOCAL FULL / ANGELICA + NEXT roadmap)
- [`docs/ANGELICA_BROWSER_EXTENSION.md`](docs/ANGELICA_BROWSER_EXTENSION.md) — MV3 capture extension guide
- [`scripts/evox3/`](scripts/evox3/) — steps `01`–`26` + demos + `run_all.sh` + `bge_m3_server.py`
- [`scripts/operator/`](scripts/operator/) — Gaming-7 SSH wrappers (`remote_bootstrap_angelica.sh`, `remote_resume_after_bge.sh`)
- [`extensions/angelica-capture/`](extensions/angelica-capture/) — ANGELICA Capture browser extension (MV3, no npm build)

**Status:** LOCAL FULL + ANGELICA + graph analytics + MCP + browser extension **DONE** on EVO-X3. Next wave: **React Flow 2D graph** (chronicle NEXT #4).

### Remote operator (Thomas)

- User runs **all commands via SSH** from another machine/room (`thomas-pashoulas@192.168.1.9` — Gaming-7 PC). Wi‑Fi DHCP can change the LAN IP; on EVO run `hostname -I` and override with `EVOX3_SSH=thomas-pashoulas@<ip>` if needed.
- **Never** instruct «go to the EVO-X3 / look at the screen / check the kiosk visually» as a primary step.
- **Always** prefer: `21_remote_verify.sh`, `09_smoke_check.sh`, `13_remote_go_live.sh`, paste script output.
- Kiosk runs on the EVO-X3 display automatically; remote confirmation is via HTTP/process probes, not physical visit.

### Cloud agent constraints

- There are **no cloud services** to start in this workspace.
- Do **not** expect `package.json` / app runtime under `/workspace` for the Second Brain itself; the Jinhua clone lives on EVO-X3 at `~/ai_apps/IncubativeSecondBrain`.
- Extension source lives in `extensions/`; app patches in `scripts/evox3/patches/`.
- Product name on the kiosk is **ANGELICA** (`16_brand_angelica.sh`).
- Cloud agent has **no SSH** to EVO-X3 — user pastes terminal output from their SSH session.

### How the user runs it (on EVO-X3 via SSH)

```bash
chmod +x scripts/evox3/*.sh
./scripts/evox3/21_remote_verify.sh
```

Smoke checks and ports are documented in the runbook (`:11434` LLM, `:8002` bge-m3, `:8000` API, `:5173` UI, Docker Postgres `:5432` / Neo4j `:7687`).

### Gotchas

- After reboot, login HTTP 500 with `Connection refused` on `:5432` means Docker compose (Postgres) did not come up. Run `25_post_reboot_resume.sh` (or `02_ensure_jinhua_clone_and_docker.sh` then start bge/api/web units). API docs can still be 200 while DB is down.
- If `05` fails with `bge-m3 server did not become healthy` after Docker is up: on EVO `./scripts/evox3/26_resume_after_bge.sh`, or from Gaming-7 `curl -fsSL https://raw.githubusercontent.com/thomaspas/thoma/cursor/evox3-ip-dhcp-c1c0/scripts/operator/remote_resume_after_bge.sh | bash` then `tail -f ~/ai_apps/angelica-resume.log` on EVO via SSH.
- Brand patches live on the EVO-X3 clone (`*.evox3-brand-orig`); re-run `16` after upstream web updates.
- Browser extension uses a **separate** Chromium profile (Load unpacked), not the kiosk.
- SSH bracketed paste (`^[[200~`) breaks hand-rolled `TOKEN=` — use `17_demo` / `18_demo` / `13` scripts.

### Lint / test / build (this repo)

- Shell scripts: `bash -n scripts/evox3/*.sh`
- Extension: `./scripts/evox3/19_browser_extension.sh` (no npm; copies MV3 source to `build/`)
- No automated test suite yet for these operator scripts.
