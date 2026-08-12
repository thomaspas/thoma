# thoma

Operator tooling for **EVO-X3 LOCAL FULL** — Jinhua Second Brain branded as **ANGELICA**.

**Status: DONE** on EVO-X3 (smoke 16/0, Greek chat, docker boot, ANGELICA UI, Neo4j graph analytics).

- Runbook: [docs/EVOX3_JINHUA_LOCAL_FULL.md](docs/EVOX3_JINHUA_LOCAL_FULL.md)
- Session chronicle (all chats + NEXT roadmap): [docs/SESSION_CHRONICLE_ANGELICA.md](docs/SESSION_CHRONICLE_ANGELICA.md)
- Scripts: [scripts/evox3/](scripts/evox3/)

On the EVO-X3 machine:

```bash
chmod +x scripts/evox3/*.sh
./scripts/evox3/run_all.sh
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
