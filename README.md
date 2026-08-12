# thoma

Operator tooling for **EVO-X3 LOCAL FULL** Jinhua Second Brain.

- Runbook: [docs/EVOX3_JINHUA_LOCAL_FULL.md](docs/EVOX3_JINHUA_LOCAL_FULL.md)
- Scripts: [scripts/evox3/](scripts/evox3/)

On the EVO-X3 machine:

```bash
chmod +x scripts/evox3/*.sh
./scripts/evox3/run_all.sh
```

Already installed? Finish / resume:

```bash
./scripts/evox3/12_operator_finish.sh
```

Remote ingest + Greek chat (SSH):

```bash
./scripts/evox3/13_remote_go_live.sh
```
