# EVO-X3 · LOCAL FULL · ANGELICA

## BLUF

Στήνουμε το [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain) **όπως το stack του Jinhua** (Postgres + Neo4j + MinIO + FastAPI + React), branded as **ANGELICA**, με:

| Κομμάτι | Τιμή |
|--------|------|
| Chat LLM | Τοπικό `llama-server` `http://127.0.0.1:11434/v1` |
| Embeddings | Τοπικό `BAAI/bge-m3` `http://127.0.0.1:8002/v1` |
| Reranker | `none` |
| UI | `http://127.0.0.1:5173` σε Chromium kiosk + autostart (**ANGELICA**) |
| Κρατάμε | Μοντέλα, Open WebUI `:8080`, SearXNG `:8888` |

Αυτό το repo (`thoma`) **δεν τρέχει** το stack στο Cursor Cloud. Περιέχει idempotent scripts· τα τρέχεις στο **EVO-X3**.

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

Μετά στην οθόνη:
1. Confirm kiosk opens **dashboard/chat** (no Register/Login) on **`:5173`**.
2. Upload `~/ai_apps/evox3-greek-smoke.md` → Greek chat smoke → reboot για autostart.
3. Μετά reboot: `systemctl --user is-active evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service` + `./scripts/evox3/09_smoke_check.sh`.
4. Αν login HTTP 500 / `Connection refused` στο `:5432`: Postgres/docker δεν ήρθε πάνω — `./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh` (εγκαθιστά και `evox3-jinhua-docker.service` για τα επόμενα reboot).

## Handoff — κατάσταση

**DONE — LOCAL FULL / ANGELICA** (2026-08-12).

Πλήρες χρονικό συνομιλιών + evidence + parked NEXT:
[`docs/SESSION_CHRONICLE_ANGELICA.md`](SESSION_CHRONICLE_ANGELICA.md)

**Branch:** `cursor/angelica-brand-kiosk-6263` → PR [#5](https://github.com/thomaspas/thoma/pull/5) (includes docker-boot fix). Merge to `main` when ready.

**Final smoke:**
```bash
cd "$HOME/thoma"
git fetch origin '+refs/heads/cursor/angelica-brand-kiosk-6263:refs/remotes/origin/cursor/angelica-brand-kiosk-6263'
git checkout -B cursor/angelica-brand-kiosk-6263 origin/cursor/angelica-brand-kiosk-6263
./scripts/evox3/09_smoke_check.sh
```

Expect **14 pass / 0 fail**, sidebar **ANGELICA**. Optional reboot + re-run `09`.

**Κανόνες επόμενου agent:** Ελληνικά για εξηγήσεις· ASCII για scripts/logs· χωρίς SSH από cloud· μόνο Flatpak browser· ποτέ kiosk στο `:8000`. Νέα features: διάβασε κεφάλαιο **NEXT** στο chronicle (analytics → MCP → extension).

## Logs

```bash
journalctl --user -u evox3-bge-m3.service -n 100 --no-pager
journalctl --user -u evox3-jinhua-api.service -n 100 --no-pager
journalctl --user -u evox3-jinhua-web.service -n 100 --no-pager
tail -n 50 /tmp/evox3-jinhua-kiosk.log
```

## Kiosk από SSH (οθόνη EVO-X3)

Το GUI ανοίγει στην τοπική οθόνη του EVO-X3. Αν τρέχεις από SSH, το script δένει `WAYLAND_DISPLAY` / `XDG_RUNTIME_DIR` / `XAUTHORITY` στο logged-in desktop session:

```bash
./scripts/evox3/10_relaunch_kiosk.sh
```

Προϋπόθεση: κάποιος logged-in στο desktop του EVO-X3.

Αν δεις `Missing X server or $DISPLAY`:
1. Επιβεβαίωσε graphical session: `ls /run/user/$(id -u)/wayland-*`
2. Ξανατρέξε από **τοπικό terminal στην οθόνη** (όχι μόνο SSH), ή
3. Πάστα diagnostic:
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
