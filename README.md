# thoma

Operator tooling for **EVO-X3 LOCAL FULL** — Jinhua Second Brain branded as **ANGELICA**.

**Status: DONE** on EVO-X3 (smoke 18/0, Greek chat, docker boot, ANGELICA UI, graph analytics, MCP server, browser extension).

- Runbook: [docs/EVOX3_JINHUA_LOCAL_FULL.md](docs/EVOX3_JINHUA_LOCAL_FULL.md)
- **Remote SSH operator:** [docs/REMOTE_OPERATOR_SSH.md](docs/REMOTE_OPERATOR_SSH.md) (Thomas runs from another PC — no screen visit)
- **Cursor Desktop → EVO-X3:** [docs/CURSOR_REMOTE_EVOX3.md](docs/CURSOR_REMOTE_EVOX3.md) (Remote SSH + Simple Browser screen preview — Desktop-only)
- Session chronicle (all chats + NEXT roadmap): [docs/SESSION_CHRONICLE_ANGELICA.md](docs/SESSION_CHRONICLE_ANGELICA.md)
- Browser extension: [docs/ANGELICA_BROWSER_EXTENSION.md](docs/ANGELICA_BROWSER_EXTENSION.md)
- Scripts: [scripts/evox3/](scripts/evox3/)
- Extension source: [extensions/angelica-capture/](extensions/angelica-capture/)

On the EVO-X3 machine (via SSH from another PC):

```bash
chmod +x scripts/evox3/*.sh
./scripts/evox3/21_remote_verify.sh
```

Already installed? Finish / resume (skip-auth + ANGELICA brand + smoke + kiosk):

```bash
./scripts/evox3/12_operator_finish.sh
```

Final smoke:

```bash
./scripts/evox3/09_smoke_check.sh
```

Brand only:

```bash
./scripts/evox3/16_brand_angelica.sh
./scripts/evox3/10_relaunch_kiosk.sh
```

Remote ingest + Greek chat (SSH):

```bash
./scripts/evox3/13_remote_go_live.sh
```

Neo4j graph analytics (opt-in):

```bash
./scripts/evox3/17_graph_analytics.sh
./scripts/evox3/09_smoke_check.sh
./scripts/evox3/17_demo_analytics.sh
```

ANGELICA MCP server (opt-in):

```bash
./scripts/evox3/18_mcp_angelica.sh
./scripts/evox3/18_demo_mcp.sh
```

Browser extension capture (opt-in):

```bash
./scripts/evox3/19_browser_extension.sh
./scripts/evox3/19_demo_capture.sh
```

Cursor Desktop on Gaming-7 (Remote SSH + watch the EVO-X3 kiosk in Simple Browser):

```bash
./scripts/evox3/25_remote_screen_preview.sh
```

Then Command Palette → `Simple Browser: Show` → `http://127.0.0.1:5174/`. See [docs/CURSOR_REMOTE_EVOX3.md](docs/CURSOR_REMOTE_EVOX3.md). Cloud agents cannot SSH or see that display.

Cursor MCP config: [docs/mcp_cursor_angelica.json.example](docs/mcp_cursor_angelica.json.example)
