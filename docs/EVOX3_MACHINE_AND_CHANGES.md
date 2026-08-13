# EVO-X3 — μηχάνημα και αλλαγές

Πηγή αλήθειας για το επόμενο agent / operator. Runtime είναι το Mini PC· αυτό το repo (`thoma`) έχει μόνο runbooks και idempotent scripts.

**Απόφαση 2026-08-13:** το Jinhua kiosk-stack είναι **off**. **ANGELICA** = [GBrain](https://github.com/garrytan/gbrain) Nate **Level 5** (always-on brain OS). Κρατάμε **μόνο το όνομα**. Δες [`ANGELICA_GBRAIN_LEVEL5.md`](ANGELICA_GBRAIN_LEVEL5.md).

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
- **Docker:** χρησιμοποιήθηκε για Jinhua Postgres `:5432` / Neo4j `:7687` / MinIO. Μετά το retire (`26`) αυτά τα compose services **δεν** πρέπει να τρέχουν.
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
11. **2026-08-13:** Jinhua stack **off** (`26`). ANGELICA = GBrain Level 5 (`27`, `28`).

## Rollback (Jinhua)

Το clone **δεν** σβήνεται στο πρώτο πέρασμα. Το `26` κάνει archive/rename του `~/ai_apps/IncubativeSecondBrain` (κρατά `.env` / uploads). Μην κάνεις `rm -rf` στο `~/models` ή σε Docker volumes χωρίς ξεχωριστή εντολή.

Rollback (χειροκίνητα, όχι default):

```bash
# restore archive name, then re-enable units — only if Thomas asks
systemctl --user enable --now evox3-jinhua-docker evox3-bge-m3 evox3-jinhua-api evox3-jinhua-web
```

## Τρέχουσα operator ροή (EVO-X3 terminal)

```bash
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
./scripts/evox3/26_retire_jinhua_kiosk.sh
./scripts/evox3/27_gbrain_angelica.sh
./scripts/evox3/28_gbrain_verify.sh
```

Paste το output του `28` στο Cloud chat. Cursor MCP: [`mcp_cursor_gbrain.json.example`](mcp_cursor_gbrain.json.example).
