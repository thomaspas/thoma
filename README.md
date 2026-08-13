# thoma

Operator tooling for **EVO-X3**.

**Status:** αλλαγή project — **πλήρες σβήσιμο Jinhua**. Κρατάμε llama / `~/models` / WebUI / SearXNG. Wipe: [docs/JINHUA_FULL_WIPE.md](docs/JINHUA_FULL_WIPE.md).

Στο Mini PC (Cursor Remote SSH `evox3`):

```bash
cd "$HOME/thoma"
git fetch origin cursor/jinhua-full-wipe-f924 && git checkout cursor/jinhua-full-wipe-f924
EVOX3_WIPE_JINHUA=YES ./scripts/evox3/29_wipe_jinhua.sh
```

- Μηχάνημα: [docs/EVOX3_MACHINE_AND_CHANGES.md](docs/EVOX3_MACHINE_AND_CHANGES.md)
- Wipe Jinhua: [docs/JINHUA_FULL_WIPE.md](docs/JINHUA_FULL_WIPE.md)
- Cursor Remote: [docs/CURSOR_REMOTE_EVOX3.md](docs/CURSOR_REMOTE_EVOX3.md)
- Chronicle: [docs/SESSION_CHRONICLE_ANGELICA.md](docs/SESSION_CHRONICLE_ANGELICA.md)

**Μην** τρέχεις `run_all.sh` / `02` / `12` μετά το wipe (ξαναστήνει Jinhua).
