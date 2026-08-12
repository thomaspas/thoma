# EVO-X3 · LOCAL FULL Jinhua Second Brain

## BLUF

Στήνουμε το [IncubativeSecondBrain](https://github.com/JinhuaChenBiggest/IncubativeSecondBrain) **όπως το stack του Jinhua** (Postgres + Neo4j + MinIO + FastAPI + React), αλλά με:

| Κομμάτι | Τιμή |
|--------|------|
| Chat LLM | Τοπικό `llama-server` `http://127.0.0.1:11434/v1` |
| Embeddings | Τοπικό `BAAI/bge-m3` `http://127.0.0.1:8002/v1` |
| Reranker | `none` |
| UI | `http://127.0.0.1:5173` σε Chromium kiosk + autostart |
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
./scripts/evox3/09_smoke_check.sh
./scripts/evox3/10_relaunch_kiosk.sh
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
curl -fsS http://127.0.0.1:11434/v1/models | head
curl -fsS http://127.0.0.1:8002/health
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8000/docs
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5173
systemctl --user status evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service --no-pager
```

Στο UI: **χωρίς Register/Login** (script `11` auto-login ως `ye@evox3.local`) → ανέβασε ένα μικρό `.md` → ρώτα στα ελληνικά.

## Skip AuthScreen (auto-seed)

```bash
./scripts/evox3/11_skip_auth_ui.sh
./scripts/evox3/10_relaunch_kiosk.sh
```

- Δημιουργεί/κάνει login τον fixed local λογαριασμό (`EVOX3_LOCAL_*`).
- Patch στο `apps/web/src/App.tsx` (+ `evox3AutoAuth.ts`) ώστε να μην εμφανίζεται ποτέ το `AuthScreen`.
- Backup upstream: `apps/web/src/App.tsx.evox3-orig`.
- Επαναφορά Register/Login:
  ```bash
  cp ~/ai_apps/IncubativeSecondBrain/apps/web/src/App.tsx.evox3-orig \
     ~/ai_apps/IncubativeSecondBrain/apps/web/src/App.tsx
  systemctl --user restart evox3-jinhua-web.service
  ```

## Συνέχεια μετά το πρώτο boot (operator checklist)

1. Pull + skip-auth + kiosk:
   ```bash
   cd "$HOME/thoma" && git pull --ff-only
   ./scripts/evox3/11_skip_auth_ui.sh
   ./scripts/evox3/10_relaunch_kiosk.sh
   ./scripts/evox3/09_smoke_check.sh
   ```
2. Confirm kiosk opens dashboard (no Register/Login) on **`:5173`**.
3. Upload a small `.md` → Greek chat smoke → reboot για autostart.

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
