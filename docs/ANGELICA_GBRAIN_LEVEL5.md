# ANGELICA = GBrain Level 5

Nate **Level 5** είναι το [GBrain](https://github.com/garrytan/gbrain) (always-on brain OS, Garry Tan). Το όνομα στο Mini PC είναι **ANGELICA**. Αυτό το repo (`thoma`) έχει μόνο operator scripts· το Cloud Agent **δεν** τρέχει εντολές στο `192.168.1.8`.

Πηγή αλήθειας μηχανήματος: [`EVOX3_MACHINE_AND_CHANGES.md`](EVOX3_MACHINE_AND_CHANGES.md).

## Τι είναι / τι δεν είναι

| Είναι | Δεν είναι |
|--------|-----------|
| GBrain + PGLite, always-on `gbrain serve` | Το live γράφο-app του Jay |
| MCP για Cursor (`gbrain serve` stdio) | Obsidian (pretty graphs = συνήθως Level 2/4) |
| Όνομα **ANGELICA** σε identity + systemd | Jinhua kiosk UI `:5173` / API `:8000` |
| Keyless keyword search χωρίς API key | `npm install -g gbrain` (άλλο πακέτο) |

**Εκτός πρώτου περάσματος:** Memory Stargraph, Claude Code `BOOTSTRAP_FOR_AGENTS.md` interview (ο Thomas ζει στο **Cursor**), wipe `~/models` / Docker volumes.

**Κρατάμε:** `llama-server` `:11434`, `~/models/`, Open WebUI `:8080`, SearXNG `:8888`.

## Operator (EVO-X3 terminal)

Από Gaming-7: SSH ή Cursor Desktop Remote SSH (`Host evox3`). Αν το prompt είναι ήδη `thomas-pashoulas-EVO-X3`, **μην** κάνεις nested `ssh 192.168.1.8`.

```bash
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
./scripts/evox3/26_retire_jinhua_kiosk.sh
./scripts/evox3/27_gbrain_angelica.sh
./scripts/evox3/28_gbrain_verify.sh
```

Paste **ολόκληρο** το output του `28` στο Cloud chat.

### Τι κάνει κάθε script

- `26` — stop/disable `evox3-jinhua-docker`, `evox3-bge-m3`, `evox3-jinhua-api`, `evox3-jinhua-web` + kiosk autostart. Archive-rename του clone. **Δεν** σκοτώνει llama/WebUI/SearXNG. **Δεν** κάνει `rm -rf`.
- `27` — Bun αν λείπει· `bun install -g github:garrytan/gbrain`· `gbrain init --pglite` στο `~/gbrain-agent` (όχι `~/thoma`)· identity `SOUL.md` / `USER.md` / `MEMORY.md` με όνομα ANGELICA (χωρίς επινόηση βιογραφίας)· user unit `angelica-gbrain.service` για `gbrain serve --http` (Level 5 always-on, loopback `:3131`).
- `28` — `gbrain --version`, `gbrain doctor`, unit active, προειδοποίηση αν το PATH έχει npm-shadow `gbrain`.

Αν δεν υπάρχουν `OPENAI_API_KEY` / `ZEROENTROPY_API_KEY` / `VOYAGE_API_KEY`, το `27` τρέχει `gbrain init --pglite --no-embedding` (keyless). Το `28` επιτρέπει doctor warnings σε αυτή τη λειτουργία.

## Cursor MCP

Αντέγραψε [`mcp_cursor_gbrain.json.example`](mcp_cursor_gbrain.json.example) στα MCP settings του Cursor (στο Remote SSH window που είναι πάνω στο EVO-X3). Το PATH πρέπει να περιλαμβάνει `$HOME/.bun/bin`. Restart MCP.

```json
{
  "mcpServers": {
    "gbrain": {
      "command": "gbrain",
      "args": ["serve"]
    }
  }
}
```

Αυτό είναι **stdio** (ο Cursor κάνει spawn το `gbrain serve`). Το systemd unit είναι ξεχωριστό: HTTP `127.0.0.1:3131` (`/admin`) ώστε το brain να μένει always-on χωρίς Cursor.

Δες και [`CURSOR_REMOTE_EVOX3.md`](CURSOR_REMOTE_EVOX3.md).

## Έλεγχοι στο μηχάνημα

```bash
gbrain --version
gbrain doctor
systemctl --user status angelica-gbrain.service --no-pager
```

Αν το `gbrain` στο PATH είναι npm package: `npm uninstall -g gbrain` και ξανά `bun install -g github:garrytan/gbrain`.

## Rollback (Jinhua)

Μόνο αν το ζητήσει ο Thomas: επαναφορά του archived clone (`~/ai_apps/IncubativeSecondBrain.archived*`) και `systemctl --user enable --now` στα `evox3-jinhua-*`. Historical runbook: [`EVOX3_JINHUA_LOCAL_FULL.md`](EVOX3_JINHUA_LOCAL_FULL.md).
