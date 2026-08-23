# ANGELICA recover NOW (EVO-X3)

**Do this on EVO** after `ssh thomas-pashoulas@192.168.1.9` from Gaming-7.

Symptoms that mean you need this:
- `Postgres :5432 CLOSED`
- `Unit evox3-*-service not found`
- docker compose still `Pulling` and you hit Ctrl+C

```bash
cd ~/thoma
git remote set-url origin https://github.com/thomaspas/thoma.git
git fetch origin
# optional: get latest recovery scripts
git fetch origin cursor/evox3-ip-dhcp-c1c0:refs/remotes/origin/cursor/evox3-ip-dhcp-c1c0 || true
git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0 2>/dev/null || true
chmod +x scripts/evox3/*.sh

# LONG — do not Ctrl+C (docker images + pip + HF model)
./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh
./scripts/evox3/run_all.sh

# Fresh .env may keep upstream LLM_MODEL=gpt-4o-mini — align to live llama:
ID=$(curl -fsS http://127.0.0.1:11434/v1/models | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"][0]["id"])')
sed -i "s|^LLM_MODEL=.*|LLM_MODEL=$ID|" ~/ai_apps/IncubativeSecondBrain/.env
systemctl --user restart evox3-jinhua-api.service 2>/dev/null || true

./scripts/evox3/21_remote_verify.sh
```

Success line to paste back to Cursor:

```text
REMOTE VERIFY OK — no physical visit needed
```

If `02` is still pulling images, leave the terminal open and wait.
