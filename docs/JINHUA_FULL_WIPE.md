# Πλήρες σβήσιμο Jinhua (αλλαγή project)

Ο Thomas αλλάζει project. Το **IncubativeSecondBrain / Jinhua kiosk / ANGELICA graph** στο EVO-X3 σβήνεται **εντελώς** (units + clone + Docker volumes + γράφημα Neo4j). Δεν ξαναστήνεται.

Αυτό το repo (`thoma`) **μένει** — είναι τα operator scripts/docs, όχι το runtime.

Cloud Agent δεν τρέχει wipe. **Cursor Remote SSH `evox3`** (Fable 5) στο Mini PC:

```bash
cd "$HOME/thoma"
git fetch origin cursor/jinhua-full-wipe-f924
git checkout cursor/jinhua-full-wipe-f924
chmod +x scripts/evox3/*.sh
EVOX3_WIPE_JINHUA=YES ./scripts/evox3/29_wipe_jinhua.sh
```

Χωρίς `EVOX3_WIPE_JINHUA=YES` το script αρνείται. Μετά από αυτό **δεν υπάρχει rollback** των δεδομένων (Postgres/Neo4j/MinIO volumes).

## Τι ΚΡΑΤΑΜΕ (όχι Jinhua)

| Στο EVO-X3 | Γιατί |
|------------|--------|
| `llama-server` `:11434` | τοπικό LLM για το επόμενο project |
| `~/models/` | GGUF (Qwen κ.λπ.) |
| Open WebUI `:8080` | ήδη υπήρχε πριν το Jinhua |
| SearXNG `:8888` | search |
| `~/thoma` | αυτό το git (runbooks) |
| GNOME / Docker engine / Flatpak Chromium | σύστημα |
| SSH `thomas-pashoulas@192.168.1.8` | operator |
| Warden/NEBULA σημειώσεις στο Gaming-7 `~/Λήψεις/` | άλλο track, εκτός αυτού του wipe |

## Τι ΣΒΗΝΕΙ (όλο το Jinhua project)

### Processes / systemd (user)

- `evox3-jinhua-docker.service` — `docker compose` Postgres + Neo4j + MinIO
- `evox3-bge-m3.service` — embeddings `:8002`
- `evox3-jinhua-api.service` — FastAPI `:8000`
- `evox3-jinhua-web.service` — Vite `:5173`
- Unit files: `~/.config/systemd/user/evox3-jinhua-*.service`, `evox3-bge-m3.service`

### Docker data (μη αναστρέψιμο)

- `docker compose down -v` μέσα στο clone → **volumes** Postgres / Neo4j / MinIO
- Κόμβοι γραφήματος, uploads, kiosk user `ye@evox3.local` / `evox3-local-12`

### Δίσκος

- `~/ai_apps/IncubativeSecondBrain` (+ `.archived*`)
- `~/ai_apps/bge-m3-server` (venv + HF model copy αν είναι εκεί)
- `~/ai_apps/bin/evox3-jinhua-kiosk.sh`

### Desktop / kiosk

- `~/.config/autostart/evox3-jinhua-kiosk.desktop`
- `~/.local/share/applications/evox3-jinhua-kiosk.desktop`
- `/tmp/evox3-jinhua-kiosk-chromium` (profile)
- `/tmp/evox3-jinhua-kiosk.log`
- kiosk Chromium process που δείχνει `:5173`

### Θύρες που πρέπει να αδειάσουν

`8000` API · `5173` UI · `8002` bge-m3 · `5432` Postgres · `7687` Neo4j · (MinIO συνήθως `9000`/`9001` αν το compose τα έκανε bind)

### Δεν σβήνουμε από το GitHub `thoma`

Τα `scripts/evox3/01`–`24` και `patches/` μένουν ως ιστορικό. Απλά **μην** τα ξανατρέξεις (`run_all.sh`, `12`, `02`…).

Προαιρετικά (όχι default στο `29`): `~/.cache/huggingface` (βάρος bge-m3) με `EVOX3_WIPE_HF_CACHE=1`. Docker **images** postgres/neo4j μένουν εκτός αν `EVOX3_WIPE_DOCKER_IMAGES=1`.

## Τι χάνεις μαζί με το Jinhua

- ANGELICA kiosk chat
- Neo4j **γράφημα** + React Flow Graph tab
- Graph analytics `17`
- Jinhua MCP `18` (remember/recall προς `:8000`)
- Browser extension προς αυτό το API
- Greek ingest documents στη Postgres

Το όνομα ANGELICA / Jarvis του επόμενου project **δεν** εξαρτάται από αυτά τα αρχεία.

## Μετά το wipe — έλεγχος

```bash
systemctl --user is-active evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service
# θέλουμε: inactive / not-found

ss -tlnp | grep -E '8000|5173|8002|5432|7687' || echo 'jinhua ports free'
curl -sS http://127.0.0.1:11434/v1/models | head
ls "$HOME/models" | head
test ! -d "$HOME/ai_apps/IncubativeSecondBrain" && echo 'clone gone'
```

Paste αυτό το output στο chat.

## Gaming-7

Δεν σβήνεις Cursor, ούτε το `~/.ssh/id_ed25519_evox3`. Το `openssh-server` που μπήκε στο Gaming-7 **δεν** είναι Jinhua — άσχετο.

Cursor Remote: ακόμα `Host evox3` → φάκελος `~/thoma`. Επόμενο project (Jarvis κ.λπ.) σε **νέο φάκελο**, όχι μέσα στο σβησμένο clone.

## Αλλαγή project (τι μένει ως βάση)

1. Mini PC + llama + μοντέλα + SearXNG + WebUI
2. Operator: Cursor Remote SSH + Fable 5
3. Άδειες θύρες `:8000` / `:5173` / `:7687` για ό,τι χτίσεις μετά
4. Jarvis του YouTube **δεν** είναι εγκατεστημένος και δεν γίνεται `git clone` από το βίντεο — χτίζεται ξεχωριστά
