# thoma

Operator tooling for **EVO-X3**. Product name **ANGELICA** = [GBrain](https://github.com/garrytan/gbrain) Nate **Level 5** (always-on brain OS). Το όνομα μόνο· όχι Jinhua kiosk.

**Status:** GBrain Level 5 — scripts `26`–`28` στο repo. Τρέξε τα στο Mini PC (SSH / Cursor Remote SSH) και paste το `28`.

- **Μηχάνημα + ιστορικό αλλαγών:** [docs/EVOX3_MACHINE_AND_CHANGES.md](docs/EVOX3_MACHINE_AND_CHANGES.md)
- **GBrain Level 5 runbook:** [docs/ANGELICA_GBRAIN_LEVEL5.md](docs/ANGELICA_GBRAIN_LEVEL5.md)
- **Cursor Desktop → EVO-X3:** [docs/CURSOR_REMOTE_EVOX3.md](docs/CURSOR_REMOTE_EVOX3.md)
- **Remote SSH operator:** [docs/REMOTE_OPERATOR_SSH.md](docs/REMOTE_OPERATOR_SSH.md)
- Session chronicle: [docs/SESSION_CHRONICLE_ANGELICA.md](docs/SESSION_CHRONICLE_ANGELICA.md)
- Historical Jinhua kiosk runbook: [docs/EVOX3_JINHUA_LOCAL_FULL.md](docs/EVOX3_JINHUA_LOCAL_FULL.md)
- Scripts: [scripts/evox3/](scripts/evox3/)

On the EVO-X3 machine (via SSH from Gaming-7 or Cursor Remote SSH):

```bash
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
./scripts/evox3/26_retire_jinhua_kiosk.sh
./scripts/evox3/27_gbrain_angelica.sh
./scripts/evox3/28_gbrain_verify.sh
```

Paste το output του `28` στο chat. Cursor MCP: [docs/mcp_cursor_gbrain.json.example](docs/mcp_cursor_gbrain.json.example).

Κρατάμε: `llama-server` `:11434`, `~/models/`, Open WebUI `:8080`, SearXNG `:8888`.

Jinhua kiosk (`:5173` / `:8000` / bge-m3 / docker Postgres) είναι **retired** — μην τρέχεις `run_all.sh` / `12_operator_finish.sh` εκτός rollback.
