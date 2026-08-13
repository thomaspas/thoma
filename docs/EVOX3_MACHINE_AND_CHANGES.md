# EVO-X3 — μηχάνημα και αλλαγές

Πηγή αλήθειας για το επόμενο agent / operator. Runtime είναι το Mini PC· αυτό το repo (`thoma`) έχει μόνο runbooks και idempotent scripts.

**Απόφαση 2026-08-13 (τελευταία):** **πλήρες σβήσιμο Jinhua** (`29_wipe_jinhua.sh`). Κρατάμε llama / models / WebUI / SearXNG. Γράφημα Neo4j χάνεται. Δες [`JINHUA_FULL_WIPE.md`](JINHUA_FULL_WIPE.md).

Παλαιότερα την ίδια μέρα: Jinhua kiosk-stack «off» / ANGELICA = GBrain — **υπερκαλύπτεται** όσο θέλουμε το γράφημα. **Μην** τρέχεις `26` (default `EVOX3_KEEP_GRAPH=1`).

## Mini PC (hardware)

| Στοιχείο | Τιμή |
|----------|------|
| Chassis | GMKtec Mini PC (EVO-X3) |
| CPU | AMD Ryzen AI Max+ 395, 16C/32T, έως 5.1 GHz |
| GPU | Radeon 8060S (40 CU) |
| RAM | LPDDR5X 8000, 64 ή 128 GB |
| Disk | NVMe (1–2 TB) |
| Net | WiFi 7, BT 5.4, 2.5G LAN, HDMI, USB4, OCuLink (όχι hot-swap) |
| Hostname | `thomas-pashoulas-EVO-X3` |
| SSH | `thomas-pashoulas@192.168.1.8` |
| Operator PC | Gaming-7 (`thomas1821-Z170X-Gaming-7`) |
| SSH key (Gaming-7 → EVO-X3 μόνο) | `~/.ssh/id_ed25519_evox3` |

Cloud agents **δεν** έχουν LAN SSH. Ο Thomas τρέχει scripts στο Mini PC μέσω Cursor Desktop Remote SSH (`Host evox3`) ή paste από SSH session.

## Πώς δουλεύει το μηχάνημα

- **Desktop:** GNOME / Wayland. User systemd (`systemctl --user`) + linger για services μετά το logout.
- **Docker:** μετά το `29`, Jinhua compose/volumes **δεν** πρέπει να υπάρχουν. Μην ξανακάνεις `docker compose up` στο παλιό clone.
- **Nested SSH:** αν το prompt είναι `thomas-pashoulas@thomas-pashoulas-EVO-X3`, **μην** κάνεις `ssh 192.168.1.8` (SSH στον εαυτό σου). Τρέξε τα scripts απευθείας από `~/thoma`.
- **Pi-hole:** δεν ήταν αίτιο για προβλήματα στο `:5173`. Το local HTTP στο loopback ήταν OK· τα kiosk fails ήταν Wayland/DISPLAY/Chromium από SSH.
- **Reboot (ιστορικό Jinhua):** login HTTP 500 με `Connection refused` στο `:5432` σήμαινε ότι το `evox3-jinhua-docker.service` δεν είχε ανέβει. Το API docs μπορούσε να είναι 200 ενώ η DB ήταν κάτω. **Πλέον** το Jinhua docker unit είναι disable· μην το ξανα-enable εκτός rollback.
- **Κρατάμε (όχι Jinhua):** `llama-server` `:11434`, μοντέλα `~/models/`, Open WebUI `:8080`, SearXNG `:8888`.
- **GBrain (τρέχον):** workspace `~/gbrain-agent` (άδειος φάκελος, **όχι** `~/thoma`), PGLite, user unit `angelica-gbrain.service` (`gbrain serve --http` loopback). Cursor MCP: stdio `gbrain serve`.

## Ιστορικό αλλαγών (σύντομο)

Από το [`SESSION_CHRONICLE_ANGELICA.md`](SESSION_CHRONICLE_ANGELICA.md):

1. Kiosk στόχος `:8000` (API docs) → σωστό UI `:5173` (Flatpak Chromium).
2. Skip-auth + seed `ye@evox3.local` (`11`).
3. Brand **ANGELICA** στο Jinhua web (`16`).
4. Ingest hang από Qwen thinking → `/no_think` + `REVIEW_ENABLED=false` (`14`, `15`).
5. Docker boot unit `evox3-jinhua-docker` ώστε Postgres `:5432` μετά από reboot (`02` / `06`).
6. Graph analytics `17` (Neo4j orphans / PageRank / Louvain / bridges).
7. Jinhua MCP `18` (`remember` / `recall` / `connect` / `analyze`).
8. Browser extension `19` + CORS `20`.
9. Remote verify `21` (SSH operator, χωρίς επίσκεψη οθόνης).
10. Cursor Desktop Remote SSH + screen preview `:5174` (`25`, ξεχωριστό PR αν δεν έχει γίνει merge).
11. **2026-08-13 πρωί:** σχέδιο GBrain Level 5 (`26`–`28`).
12. **2026-08-13 απόγευμα:** σκέψη «ANGELICA = μόνο γράφημα».
13. **2026-08-13 νύχτα:** πλήρες wipe Jinhua (`29`) — αλλαγή project. [`JINHUA_FULL_WIPE.md`](JINHUA_FULL_WIPE.md).

## Rollback (Jinhua)

Μετά το `29` **δεν** υπάρχει rollback δεδομένων (volumes σβησμένα). Ξαναστήσιμο μόνο με `run_all.sh` από μηδέν — μην το κάνεις εκτός αν το ζητήσει ρητά ο Thomas. `~/models` δεν σβήνεται ποτέ από το `29`.

## Τρέχουσα operator ροή (EVO-X3 terminal)

```bash
cd "$HOME/thoma"
git fetch origin cursor/jinhua-full-wipe-f924
git checkout cursor/jinhua-full-wipe-f924
EVOX3_WIPE_JINHUA=YES ./scripts/evox3/29_wipe_jinhua.sh
```

Λεπτομέρειες: [`JINHUA_FULL_WIPE.md`](JINHUA_FULL_WIPE.md).
