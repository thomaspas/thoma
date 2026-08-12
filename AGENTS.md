# AGENTS.md

## Cursor Cloud specific instructions

This repository (`thomaspas/thoma`) holds **EVO-X3 LOCAL FULL** runbooks and idempotent scripts for deploying [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain) on the user's local machine. It is not the runtime host for Docker/LLM services.

### What lives here

- [`docs/EVOX3_JINHUA_LOCAL_FULL.md`](docs/EVOX3_JINHUA_LOCAL_FULL.md) — operator runbook
- [`scripts/evox3/`](scripts/evox3/) — steps `01`–`08` + `run_all.sh` + `bge_m3_server.py`

### Cloud agent constraints

- There are **no cloud services** to start in this workspace.
- Do **not** expect `package.json` / app runtime under `/workspace` for the Second Brain itself; the Jinhua clone lives on EVO-X3 at `~/ai_apps/IncubativeSecondBrain`.
- Do not invent a second app stack here. Changes should stay in docs/scripts unless the user asks otherwise.

### How the user runs it (on EVO-X3)

```bash
chmod +x scripts/evox3/*.sh
./scripts/evox3/run_all.sh
```

Smoke checks and ports are documented in the runbook (`:11434` LLM, `:8002` bge-m3, `:8000` API, `:5173` UI).

### Lint / test / build (this repo)

- Shell scripts: `bash -n scripts/evox3/*.sh`
- No automated test suite yet for these operator scripts.
