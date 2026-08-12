# AGENTS.md

## Cursor Cloud specific instructions

This repository (`thomaspas/thoma`) holds **EVO-X3 LOCAL FULL** runbooks and idempotent scripts for deploying [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain) on the user's machine as **ANGELICA**. It is not the runtime host for Docker/LLM services.

### What lives here

- [`docs/EVOX3_JINHUA_LOCAL_FULL.md`](docs/EVOX3_JINHUA_LOCAL_FULL.md) — operator runbook
- [`docs/SESSION_CHRONICLE_ANGELICA.md`](docs/SESSION_CHRONICLE_ANGELICA.md) — saved conversation chronicle (DONE LOCAL FULL / ANGELICA + NEXT roadmap)
- [`scripts/evox3/`](scripts/evox3/) — steps `01`–`16` + `run_all.sh` + `bge_m3_server.py` (`12` finish, `13` remote go-live, `14` LLM no-think, `15` ingest diagnose, `16` ANGELICA brand)

**Status:** LOCAL FULL + ANGELICA kiosk branding is **DONE** on EVO-X3. Next feature wave is parked in the chronicle (graph analytics → MCP → extension).

### Cloud agent constraints

- There are **no cloud services** to start in this workspace.
- Do **not** expect `package.json` / app runtime under `/workspace` for the Second Brain itself; the Jinhua clone lives on EVO-X3 at `~/ai_apps/IncubativeSecondBrain`.
- Do not invent a second app stack here. Changes should stay in docs/scripts unless the user asks otherwise.
- Product name on the kiosk is **ANGELICA** (`16_brand_angelica.sh`).

### How the user runs it (on EVO-X3)

```bash
chmod +x scripts/evox3/*.sh
./scripts/evox3/run_all.sh
```

Smoke checks and ports are documented in the runbook (`:11434` LLM, `:8002` bge-m3, `:8000` API, `:5173` UI, Docker Postgres `:5432` / Neo4j `:7687`).

### Gotchas

- After reboot, login HTTP 500 with `Connection refused` on `:5432` means Docker compose (Postgres) did not come up. Run `02_ensure_jinhua_clone_and_docker.sh` (installs `evox3-jinhua-docker.service`). API docs can still be 200 while DB is down.
- Cloud agent has no SSH to EVO-X3 — validate via user paste of script output.
- Brand patches live on the EVO-X3 clone (`*.evox3-brand-orig`); re-run `16` after upstream web updates.

### Lint / test / build (this repo)

- Shell scripts: `bash -n scripts/evox3/*.sh`
- No automated test suite yet for these operator scripts.
