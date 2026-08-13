# MEMORY

Facts from operator docs. Do not invent extra history.

## 2026-08-13

- Decision: Jinhua kiosk stack **off**. ANGELICA = GBrain Level 5 (name only).
- Keep: `llama-server` `:11434`, models in `~/models/`, Open WebUI `:8080`, SearXNG `:8888`.
- Retired (disable, not wipe): `evox3-jinhua-docker`, `evox3-bge-m3`, `evox3-jinhua-api`, `evox3-jinhua-web`, kiosk autostart / Chromium `:5173`.
- Brain workspace: `~/gbrain-agent` (empty dir, **not** `~/thoma`).
- Never `npm install -g gbrain` (unrelated npm package). Install only `bun install -g github:garrytan/gbrain`.
- Out of first pass: Memory Stargraph, Claude Code bootstrap interview, wipe of `~/models` / Docker volumes.

## Hardware (EVO-X3)

- GMKtec Mini PC, AMD Ryzen AI Max+ 395 (16C/32T), Radeon 8060S, LPDDR5X 64/128 GB, NVMe
- Desktop: GNOME / Wayland; user systemd

## Historical (Jinhua, retired)

- Kiosk UI moved from API docs `:8000` to Vite `:5173`
- Skip-auth + brand ANGELICA, ingest `/no_think`, docker boot unit for Postgres `:5432`
- Graph analytics `17`, Jinhua MCP `18`, browser extension `19`, remote verify `21`
- Pi-hole was not the cause of `:5173` issues (local HTTP was OK)
