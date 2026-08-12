# ANGELICA / EVO-X3 — Session Chronicle

Saved handoff of cloud-agent conversations that built **LOCAL FULL** and branded the kiosk as **ANGELICA**. Runtime lives on the EVO-X3 machine; this repo (`thoma`) holds operator scripts and docs only.

**Status:** DONE — LOCAL FULL + ANGELICA (2026-08-12).

## Cloud agents (timeline)

| Order | Name | bcId | Focus |
|-------|------|------|--------|
| 1 | Cursor chat environment setup | [bc-2822addd…](https://cursor.com/agents/bc-2822addd-e038-4e77-8521-8e3f4bba02ac) | Migrate-to-builds; start Jinhua LOCAL FULL scripts `01`–`08` |
| 2 | Πρότζεκτ συνέχεια | [bc-c26090aa…](https://cursor.com/agents/bc-c26090aa-6493-4788-8087-72e7e82bad0a) | Flatpak kiosk, Wayland SSH, skip-auth plan |
| 3 | Project continuation status | [bc-433887f8…](https://cursor.com/agents/bc-433887f8-f959-4252-84f0-1b2168336287) | Operator finish, ingest hang, Greek chat go-live |
| 4 | Debugging project συνέχεια | [bc-ade6d950…](https://cursor.com/agents/bc-ade6d950-16c6-4e77-9fb3-d8daabb96263) | Post-reboot Postgres 500, docker boot unit, ANGELICA brand |

Also: Fresh-agent build smoke test ([bc-57e08ce7…](https://cursor.com/agents/bc-57e08ce7-6df1-50dc-a5ce-cb1eab80b0bb)) for environment builds.

## What was built (`thoma`)

Scripts under [`scripts/evox3/`](../scripts/evox3/):

| Script | Role |
|--------|------|
| `01`–`08` | Stop legacy, Docker compose, `.env`, venv, bge-m3, API, Vite kiosk, autostart |
| `09` | Smoke (ports, units, LLM align, skip-auth, Postgres/Neo4j, ANGELICA brand) |
| `10` | Relaunch Flatpak Chromium kiosk on `:5173` (Wayland-aware) |
| `11` | Skip AuthScreen + seed `ye@evox3.local` |
| `12` | Operator finish (git sync, `11`, `16`, smoke, kiosk, sample `.md`) |
| `13` | Remote go-live: upload → wait `indexed` → Greek chat |
| `14` | Local LLM `/no_think` + timeouts (Qwen thinking hang) |
| `15` | Ingest diagnose + optional sync re-ingest |
| `16` | Brand UI **ANGELICA** (title, sidebar, Greek footer prompts) |
| `17` | Neo4j graph analytics APIs (stdlib: orphans, PageRank, Louvain, bridges, shortest path) |

Runbook: [`EVOX3_JINHUA_LOCAL_FULL.md`](EVOX3_JINHUA_LOCAL_FULL.md).

App clone on EVO-X3: `~/ai_apps/IncubativeSecondBrain` (upstream [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain)).

## Bugs fixed (with evidence)

1. **Kiosk opened API docs (`:8000`)** — use Flatpak Chromium + wrapper targeting `:5173`.
2. **SSH kiosk / Missing X server** — bind `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR` / `XAUTHORITY`.
3. **Register/Login unwanted** — `11_skip_auth_ui.sh`; footer `Kiosk · always signed in`.
4. **Ingest stuck `parsing`** — Qwen thinking monopolized llama; `REVIEW_ENABLED=false`, `14` `/no_think`, sync re-ingest via `15`.
5. **Greek chat without citations** — fixed after ingest `indexed`; reply cited `ye@evox3.local`, `evidence_status: citation_complete`.
6. **Post-reboot login HTTP 500** — Postgres `:5432` Connection refused; `evox3-jinhua-docker.service` + API `ExecStartPre` wait for 5432.
7. **Single-branch clone / missing `origin/main`** — explicit fetch refspec in `12`.

## Verification evidence (EVO-X3)

- Stack: llama `:11434`, bge-m3 `:8002`, API `:8000`, web `:5173`, Postgres/Neo4j/MinIO via compose.
- Greek chat go-live: document `e9c50037-…` → `indexed`; answer cited kiosk user from note.
- After docker-boot fix: smoke **13 pass / 0 fail**, login OK.
- After `16_brand_angelica.sh`: smoke **14 pass / 0 fail**, `ANGELICA brand present`; kiosk relaunched on `:5173`.

## Pull requests

| PR | Title | State |
|----|-------|--------|
| [#1](https://github.com/thomaspas/thoma/pull/1) | EVO-X3 LOCAL FULL runbook + scripts | MERGED |
| [#2](https://github.com/thomaspas/thoma/pull/2) | Prefer main in operator finish | MERGED |
| [#3](https://github.com/thomaspas/thoma/pull/3) | Remote go-live / ingest / no-think | MERGED |
| [#4](https://github.com/thomaspas/thoma/pull/4) | Docker boot / Postgres smoke | Superseded by #5 |
| [#5](https://github.com/thomaspas/thoma/pull/5) | ANGELICA brand (+ includes #4 commits) | Ready for merge to `main` |

Working branch on machine: `cursor/angelica-brand-kiosk-6263`.

## Ports / units (quick ref)

- LLM `11434` · embeddings `8002` · API `8000` · UI `5173` · Postgres `5432` · Neo4j `7687`
- User units: `evox3-jinhua-docker`, `evox3-bge-m3`, `evox3-jinhua-api`, `evox3-jinhua-web`
- Kiosk account: `ye@evox3.local` (local-only)

## Final smoke (EVO-X3)

```bash
cd "$HOME/thoma"
git fetch origin '+refs/heads/cursor/angelica-brand-kiosk-6263:refs/remotes/origin/cursor/angelica-brand-kiosk-6263'
git checkout -B cursor/angelica-brand-kiosk-6263 origin/cursor/angelica-brand-kiosk-6263
./scripts/evox3/09_smoke_check.sh
```

Expect **14 pass / 0 fail**, sidebar title **ANGELICA**. Optional: `sudo reboot` then re-run `09`.

## NEXT

Ordered follow-ups from the upgrade brief (adapt gradually):

1. **Graph analytics** on Neo4j (Louvain, PageRank, orphans, bridges, shortest path) — **IN PROGRESS** via `17_graph_analytics.sh` (branch `cursor/neo4j-graph-analytics-bd38`)
2. **MCP server** for ANGELICA (`remember` / `recall` / `connect` / `analyze`)
3. **Browser extension** capture (Plasmo / project-nexus style)
4. **React Flow 2D** visual graph + rich relation types + growth animations
5. Later: Obsidian Canvas export, spaced repetition, dream-sequence maintenance, 3D galaxy
6. “100% offline Ollama” is low priority here — LOCAL FULL already uses local llama-server + bge-m3

## Agent rules for resume

- Greek for explanations; ASCII for scripts/logs
- No SSH from Cursor Cloud — validate via paste from EVO-X3
- Flatpak browser only; never kiosk on `:8000`
- Prefer patches/scripts in `thoma` over forking app source into this repo
