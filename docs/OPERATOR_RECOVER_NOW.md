# ANGELICA recover NOW (EVO-X3)

## 0) 10-second status (paste to Cursor first)

Από **Gaming-7** ή ήδη στο **EVO** (ίδιο curl — αν είσαι στο EVO δεν κάνει nested SSH):

```bash
curl -fsSL https://raw.githubusercontent.com/thomaspas/thoma/cursor/evox3-ip-dhcp-c1c0/scripts/operator/remote_status_dump.sh | bash
```

**Καλύτερο UX:** Cursor Desktop → Remote-SSH → `evox3` (βλ. [`CURSOR_REMOTE_EVOX3.md`](CURSOR_REMOTE_EVOX3.md)) — το terminal είναι ήδη το EVO.

## 1) Resume after `05` bge timeout (tmux on EVO)

```bash
curl -fsSL https://raw.githubusercontent.com/thomaspas/thoma/cursor/evox3-ip-dhcp-c1c0/scripts/operator/remote_resume_after_bge.sh | bash
ssh thomas-pashoulas@192.168.1.9 'tail -f ~/ai_apps/angelica-resume.log'
```

Paste the end of that log to Cursor when you see:

```text
REMOTE VERIFY OK — no physical visit needed
```

---

## Or on EVO after SSH to `.9`

Symptoms: `05` timed out on bge health; API/web units missing; `LLM_MODEL=gpt-4o-mini`.

```bash
cd ~/thoma
git remote set-url origin https://github.com/thomaspas/thoma.git
git fetch origin cursor/evox3-ip-dhcp-c1c0
git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0
chmod +x scripts/evox3/*.sh
./scripts/evox3/26_resume_after_bge.sh
```

`26` now: ensures Postgres/.env/venv → installs fixed bge server → waits for `/health` → aligns `LLM_MODEL` → runs `06`–`11`/`16`/`10`/`21`.

---

## Full wipe / units not found / docker still pulling

Do **not** Ctrl+C during image pulls.

```bash
cd ~/thoma
git remote set-url origin https://github.com/thomaspas/thoma.git
git fetch origin cursor/evox3-ip-dhcp-c1c0
git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0
chmod +x scripts/evox3/*.sh
./scripts/evox3/25_post_reboot_resume.sh
```

Or from Gaming-7:

```bash
curl -fsSL https://raw.githubusercontent.com/thomaspas/thoma/cursor/evox3-ip-dhcp-c1c0/scripts/operator/remote_bootstrap_angelica.sh | bash
```
