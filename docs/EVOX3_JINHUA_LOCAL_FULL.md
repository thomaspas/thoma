# EVO-X3 · LOCAL FULL · ANGELICA (historical)

> **2026-08-13:** αυτό το runbook είναι **ιστορικό**. ANGELICA = GBrain Level 5. Μην τρέχεις `run_all.sh` / `12` εκτός rollback. Τρέχον: [`ANGELICA_GBRAIN_LEVEL5.md`](ANGELICA_GBRAIN_LEVEL5.md), μηχάνημα: [`EVOX3_MACHINE_AND_CHANGES.md`](EVOX3_MACHINE_AND_CHANGES.md).

## BLUF

Στήνουμε το [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain) **όπως το stack του Jinhua** (Postgres + Neo4j + MinIO + FastAPI + React), branded as **ANGELICA**, με:

| Κομμάτι | Τιμή |
|--------|------|
| Chat LLM | Τοπικό `llama-server` `http://127.0.0.1:11434/v1` |
| Embeddings | Τοπικό `BAAI/bge-m3` `http://127.0.0.1:8002/v1` |
| Reranker | `none` |
| UI | `http://127.0.0.1:5173` σε Chromium kiosk + autostart (**ANGELICA**) |
| Κρατάμε | Μοντέλα, Open WebUI `:8080`, SearXNG `:8888` |

Αυτό το repo (`thoma`) **δεν τρέχει** το stack στο Cursor Cloud. Περιέχει idempotent scripts· τα τρέχεις στο **EVO-X3** μέσω **SSH** από άλλο PC (άλλο δωμάτιο). Δες [`REMOTE_OPERATOR_SSH.md`](REMOTE_OPERATOR_SSH.md).

## Προϋποθέσεις στο EVO-X3

- Docker + Compose
- Node.js / npm
- Python 3.11+
- `llama-server` ήδη στο `:11434` (μοντέλο Qwen στο `~/models/`)
- Desktop session για kiosk (`DISPLAY=:0`)

## Γρήγορη διαδρομή

Από το clone του `thoma` (ή αφού κάνεις `git pull`):

```bash
cd /path/to/thoma
chmod +x scripts/evox3/*.sh
./scripts/evox3/run_all.sh
```

Ή βήμα-βήμα:

```bash
./scripts/evox3/01_stop_legacy_mvp.sh
./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh
./scripts/evox3/03_write_local_env.sh
./scripts/evox3/04_install_python_deps.sh
./scripts/evox3/05_start_bge_m3_server.sh   # HF download στο πρώτο run
./scripts/evox3/06_migrate_and_start_api.sh
./scripts/evox3/07_start_frontend_and_kiosk.sh
./scripts/evox3/08_autostart_desktop.sh
./scripts/evox3/11_skip_auth_ui.sh          # auto-seed + skip AuthScreen
./scripts/evox3/16_brand_angelica.sh        # sidebar/title/footer → ANGELICA
./scripts/evox3/09_smoke_check.sh
./scripts/evox3/10_relaunch_kiosk.sh
```

Ή τελείωμα / resume (sync branch + smoke + kiosk + sample note):

```bash
./scripts/evox3/12_operator_finish.sh
```

Default install path στο μηχάνημα: `~/ai_apps/IncubativeSecondBrain`.

## Τι κάνει κάθε script

1. **01** — Σταματά legacy `second-brain.service` (απελευθερώνει `:8000`).
2. **02** — Clone Jinhua + `docker compose up -d`.
3. **03** — Γράφει `.env` LOCAL FULL (`LLM`→`:11434`, `EMBED`→`:8002`, `WORKER_DISPATCH=inline`, `RERANKER_PROVIDER=none`). Auto-detect `LLM_MODEL` από `llama-server /v1/models` (κρατά existing μη-placeholder τιμή).
4. **04** — venv + `pip install -e ".[dev,llm]"` (Tsinghua/Aliyun mirrors).
5. **05** — Τοπικός OpenAI-compatible bge-m3 server + `evox3-bge-m3.service`.
6. **06** — `init_db()` (SQLAlchemy `create_all` + Alembic) + `evox3-jinhua-api.service`.
7. **07** — `npm install` / Vite `:5173` + Chromium/Flatpak `--kiosk`.
8. **08** — Enable units + `~/.config/autostart` kiosk wrapper (Flatpak preferred).
9. **09** — Smoke check (ports + units + LLM_MODEL alignment) + next steps.
10. **10** — Kill stale browsers + relaunch kiosk on `:5173` (Wayland-aware).
11. **11** — Auto-seed fixed local user + patch UI to **skip AuthScreen** (no Register/Login).
12. **12** — Operator finish: git sync + skip-auth + **ANGELICA brand** + smoke + kiosk + sample Greek `.md`.
13. **13** — Remote go-live: upload → wait `indexed` → Greek chat.
14. **14** — Patch local OpenAI LLM client (`/no_think`, timeouts).
15. **15** — Diagnose stuck ingest; optional sync re-ingest.
16. **16** — Brand kiosk as **ANGELICA** (title, sidebar logo, Greek footer prompts).
17. **17** — Neo4j graph analytics APIs (orphans, PageRank, Louvain, bridges, shortest path). Opt-in; not in `run_all`.
18. **17_demo** — Login + demo all `/graph/analytics/*` endpoints (no TOKEN paste).
19. **18** — ANGELICA stdio MCP server (remember / recall / connect / analyze). Opt-in.
20. **18_demo** — Demo MCP tool flows without Cursor.
21. **19** — Stage ANGELICA Capture browser extension (MV3) + optional CORS patch (`20`).
22. **19_demo** — curl-only upload smoke (simulated extension capture).
23. **20** — Patch FastAPI CORS for `chrome-extension://` origins (idempotent).
24. **21** — Remote verify (SSH operator): smoke + HTML brand + kiosk process — no screen visit.

## Overrides (env)

| Variable | Default |
|----------|---------|
| `EVOX3_JINHUA_DIR` | `$HOME/ai_apps/IncubativeSecondBrain` |
| `EVOX3_LLM_BASE_URL` | `http://127.0.0.1:11434/v1` |
| `EVOX3_EMBED_BASE_URL` | `http://127.0.0.1:8002/v1` |
| `EVOX3_LLM_MODEL` | `auto` (probe `:11434/v1/models`) |
| `EVOX3_API_PORT` | `8000` |
| `EVOX3_WEB_PORT` | `5173` |
| `EVOX3_BGE_PORT` | `8002` |
| `EVOX3_LOCAL_EMAIL` | `ye@evox3.local` |
| `EVOX3_LOCAL_PASSWORD` | `evox3-local-12` |
| `EVOX3_LOCAL_DISPLAY_NAME` | `Ye` |
| `EVOX3_BRAND_NAME` | `ANGELICA` |
| `EVOX3_BRAND_TAGLINE` | `Local second brain` |
| `EVOX3_BRAND_MARK` | `AN` |
| `EVOX3_BRAND_TITLE` | `ANGELICA · Local second brain` |

`03_write_local_env.sh` also forces `REVIEW_ENABLED=false` so ingest does not stop at human review on the kiosk.

## Remote go-live (SSH): ingest + Greek chat

Document status stays **`parsing`** while the local LLM drafts cards (slow on Qwen 27B). Do **not** start `/assistant/chat` until status is `indexed` — concurrent chat competes for the single llama slot.

```bash
./scripts/evox3/13_remote_go_live.sh
# or resume an existing upload:
./scripts/evox3/13_remote_go_live.sh e9c50037-767c-45d9-9212-1dc8d2a42643
```

If status stays **`parsing`** for minutes (Qwen thinking / hung llama slot):

```bash
./scripts/evox3/14_patch_openai_llm_local.sh   # timeout + /no_think
./scripts/evox3/15_diagnose_ingest.sh <document_id>
# foreground re-ingest with traceback:
EVOX3_FORCE_SYNC_INGEST=1 ./scripts/evox3/15_diagnose_ingest.sh <document_id>
```

After `REVIEW_ENABLED` / LLM patch change: ensure API restarted (`14` does this; or `systemctl --user restart evox3-jinhua-api.service`).

## Graph analytics (Neo4j)

Opt-in patch — stdlib algorithms on a user-scoped Neo4j export (no GDS / networkx). **Verified on EVO-X3** (smoke 16/0; demo summary 7 entities / 4 edges).

```bash
./scripts/evox3/17_graph_analytics.sh
./scripts/evox3/09_smoke_check.sh   # expects analytics patch + summary HTTP 200
./scripts/evox3/17_demo_analytics.sh  # login + hit analytics endpoints (no TOKEN paste)
```

Prefer `17_demo_analytics.sh` over hand-rolled `TOKEN=` curls — SSH bracketed paste can break login.

## MCP server (ANGELICA)

Stdio MCP server for Cursor / Claude Desktop — tools call the local FastAPI (separate from Jinhua coordinator `MCP_ENABLED=false`).

```bash
./scripts/evox3/18_mcp_angelica.sh
./scripts/evox3/18_demo_mcp.sh
```

- `analyze` tool requires graph analytics: run `17` first.
- Cursor config template: [`docs/mcp_cursor_angelica.json.example`](mcp_cursor_angelica.json.example)
- After `18` on EVO-X3: machine-specific snippet at `docs/mcp_cursor_angelica.generated.json`

Restore: remove `$EVOX3_JINHUA_DIR/scripts/angelica_mcp_*.py` and marker `.evox3-mcp-angelica`.

Restore upstream graph router/schemas: `*.evox3-graph-orig` + remove `secondbrain/graph/analytics.py` + marker `.evox3-graph-analytics`.

## Browser extension (ANGELICA Capture)

MV3 Chromium extension — capture page or selection → `POST /documents/upload`. Full guide: [`ANGELICA_BROWSER_EXTENSION.md`](ANGELICA_BROWSER_EXTENSION.md).

```bash
./scripts/evox3/19_browser_extension.sh
./scripts/evox3/19_demo_capture.sh   # curl-only upload smoke (no browser)
```

- Load unpacked from `extensions/angelica-capture/build/chrome-mv3-prod` in Chromium (not kiosk).
- Default API: `http://127.0.0.1:8000`, account `ye@evox3.local`.
- `20_patch_cors_extension.sh` runs automatically from `19` (skip with `EVOX3_SKIP_CORS_PATCH=1`).

Παράδειγμα άλλου API port αν το `:8000` είναι πιασμένο:

```bash
EVOX3_API_PORT=8010 ./scripts/evox3/06_migrate_and_start_api.sh
```

## Έλεγχοι (smoke)

```bash
./scripts/evox3/09_smoke_check.sh
```

Ή χειροκίνητα:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
# Postgres must be up — login 500 after reboot is usually :5432 refused
(echo >/dev/tcp/127.0.0.1/5432) && echo postgres_ok
curl -fsS http://127.0.0.1:11434/v1/models | head
curl -fsS http://127.0.0.1:8002/health
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8000/docs
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5173
systemctl --user status evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service --no-pager
```

Στο UI: **χωρίς Register/Login** (script `11` auto-login ως `ye@evox3.local`) → ανέβασε ένα μικρό `.md` → ρώτα στα ελληνικά.

## Skip AuthScreen (auto-seed)

```bash
./scripts/evox3/11_skip_auth_ui.sh
./scripts/evox3/16_brand_angelica.sh
./scripts/evox3/10_relaunch_kiosk.sh
```

- Δημιουργεί/κάνει login τον fixed local λογαριασμό (`EVOX3_LOCAL_*`).
- Patch στο `apps/web/src/App.tsx` (+ `evox3AutoAuth.ts`) ώστε να μην εμφανίζεται ποτέ το `AuthScreen`.
- Kiosk: **Sign out** κρύβεται / είναι no-op (`Kiosk · always signed in`) — αποφεύγει error μετά από logout.
- **16** brands title/sidebar as **ANGELICA** + Greek footer prompts (`*.evox3-brand-orig` backups).
- Backup upstream skip-auth: `apps/web/src/App.tsx.evox3-orig`.
- Επαναφορά Register/Login:
  ```bash
  cp ~/ai_apps/IncubativeSecondBrain/apps/web/src/App.tsx.evox3-orig \
     ~/ai_apps/IncubativeSecondBrain/apps/web/src/App.tsx
  systemctl --user restart evox3-jinhua-web.service
  ```

## Συνέχεια μετά το πρώτο boot (operator checklist)

One-shot finish (sync PR branch + smoke + kiosk + sample `.md`):

```bash
cd "$HOME/thoma"
chmod +x scripts/evox3/*.sh
./scripts/evox3/12_operator_finish.sh
```

## Remote verification (SSH — άλλο δωμάτιο)

Ο operator τρέχει εντολές από SSH (`thomas-pashoulas@192.168.1.8`) — **όχι** φυσική επίσκεψη στο EVO-X3. Οδηγός: [`REMOTE_OPERATOR_SSH.md`](REMOTE_OPERATOR_SSH.md).

```bash
./scripts/evox3/21_remote_verify.sh
```

1. Αναμενόμενο: `REMOTE VERIFY OK` + smoke 18/0.
2. Upload + Greek chat (χωρίς UI): `./scripts/evox3/13_remote_go_live.sh`
3. Μετά reboot (από SSH): `./scripts/evox3/09_smoke_check.sh` + `21_remote_verify.sh`
4. Αν login HTTP 500 / `:5432` refused: `./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh`

## Handoff — κατάσταση

**DONE — LOCAL FULL / ANGELICA / analytics / MCP / browser extension** (2026-08-12).

Πλήρες χρονικό συνομιλιών + evidence + NEXT roadmap:
[`docs/SESSION_CHRONICLE_ANGELICA.md`](SESSION_CHRONICLE_ANGELICA.md)

**Branch:** `main` → https://github.com/thomaspas/thoma

**Resume paste (EVO-X3 via SSH):**
```bash
cd "$HOME/thoma"
git fetch origin '+refs/heads/cursor/land-angelica-stack-8dd2:refs/remotes/origin/cursor/land-angelica-stack-8dd2'
git checkout -B cursor/land-angelica-stack-8dd2 origin/cursor/land-angelica-stack-8dd2
chmod +x scripts/evox3/*.sh
./scripts/evox3/21_remote_verify.sh       # remote OK — no screen visit
./scripts/evox3/13_remote_go_live.sh       # upload + Greek chat (SSH)
./scripts/evox3/18_demo_mcp.sh             # optional MCP demo
```

Optional reboot smoke (from SSH): `sudo reboot` then `./scripts/evox3/21_remote_verify.sh`.

**Κανόνες επόμενου agent:** Ελληνικά για εξηγήσεις· ASCII για scripts/logs· χωρίς SSH από cloud· **Thomas τρέχει μόνο από SSH (άλλο PC/δωμάτιο) — μην ζητάς «πήγαινε στην οθόνη»**· χρησιμοποίησε `21_remote_verify.sh` + paste output· μόνο Flatpak browser· ποτέ kiosk στο `:8000`.

## Logs

```bash
journalctl --user -u evox3-bge-m3.service -n 100 --no-pager
journalctl --user -u evox3-jinhua-api.service -n 100 --no-pager
journalctl --user -u evox3-jinhua-web.service -n 100 --no-pager
tail -n 50 /tmp/evox3-jinhua-kiosk.log
```

## Kiosk από SSH (οθόνη EVO-X3 — remote operator)

Το GUI ανοίγει στην τοπική οθόνη του EVO-X3. Ο operator **δεν** χρειάζεται να πάει στο μηχάνημα — επιβεβαίωση με `./scripts/evox3/21_remote_verify.sh`. Από SSH, το script δένει `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR` / `XAUTHORITY` στο logged-in desktop session:

```bash
./scripts/evox3/10_relaunch_kiosk.sh
```

Προϋπόθεση: logged-in desktop session στο EVO-X3 (αυτόματο autostart).

Αν δεις `Missing X server or $DISPLAY`:
1. Επιβεβαίωσε graphical session από SSH: `ls /run/user/$(id -u)/wayland-*`
2. Ξανατρέξε `./scripts/evox3/10_relaunch_kiosk.sh` και `./scripts/evox3/21_remote_verify.sh`
3. Πάστα diagnostic (μην πας στο μηχάνημα εκτός αν SSH probes αποτύχουν):
   ```bash
   echo "UID=$(id -u) XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
   ls -l /run/user/$(id -u)/wayland-* /run/user/$(id -u)/bus /run/user/$(id -u)/gdm/Xauthority 2>&1 | head
   loginctl show-session "$(loginctl | awk -v u="$USER" '$3==u {print $1; exit}')" -p Type -p Display -p Remote 2>&1
   ```

## Troubleshooting

### `NoSuchTableError: memories` during Alembic
Cause: running bare `alembic upgrade head` on an empty DB. Jinhua expects `init_db()` first (`create_all` + then Alembic). Script `06` does this correctly — pull the latest `thoma` branch and re-run from `06`.

```bash
cd "$HOME/thoma" && git pull --ff-only
"$HOME/thoma/scripts/evox3/06_migrate_and_start_api.sh"
```

### `LLM_MODEL` mismatch / chat fails against llama-server
Cause: `.env` had placeholder `qwen` while `/v1/models` returns the full GGUF path/id. Script `03` now auto-detects. Re-run:

```bash
cd "$HOME/thoma" && git pull --ff-only
"$HOME/thoma/scripts/evox3/03_write_local_env.sh"
systemctl --user restart evox3-jinhua-api.service
"$HOME/thoma/scripts/evox3/09_smoke_check.sh"
```

### Kiosk shows API docs instead of UI
Cause: stale Flatpak Chromium still pointed at `:8000`, or old `~/ai_apps/bin/evox3-jinhua-kiosk.sh`. Apt chromium is unavailable on this node (PackageKit masked / broken packages) — use Flatpak only.

```bash
cd "$HOME/thoma" && git pull --ff-only
./scripts/evox3/10_relaunch_kiosk.sh
# process args must show :5173, never :8000
pgrep -af 'chromium|ungoogled' | head
```

## Εκτός scope αυτού του pass

- Επανεγκατάσταση Windows / αλλαγές GRUB RAM
- Warden / Arena phantoms
- DeepSeek / SiliconFlow cloud keys
- Native Electron packaging
