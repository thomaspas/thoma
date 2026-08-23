# Remote operator — SSH only

Ο operator (Thomas) τρέχει **όλες** τις εντολές από **άλλο PC** μέσω SSH — όχι δίπλα στον EVO-X3.

| Στοιχείο | Τιμή |
|----------|------|
| EVO-X3 | `thomas-pashoulas@192.168.1.9` (Wi‑Fi — DHCP μπορεί να αλλάξει) |
| Override | `export EVOX3_SSH=thomas-pashoulas@<ip>` |
| Operator PC | Gaming-7 (ή άλλο) — μόνο terminal + paste output |
| Kiosk | Ανοίγει αυτόματα στον EVO-X3 (`:5173`) — **δεν** χρειάζεται επίσκεψη |

## Κανόνας για agents

- **Μην** ζητάς «πήγαινε στον EVO-X3 / κοίτα την οθόνη / δες το kiosk» ως πρώτο βήμα.
- **Ναι:** SSH εντολές + paste του script output στο chat.
- Cloud agent: δεν έχει SSH — ο χρήστης κάνει paste από το EVO-X3 terminal.

## Αν `No route to host` / λάθος IP

Το EVO είναι σε Wi‑Fi (`wlp…`); το LAN IP αλλάζει με DHCP (π.χ. παλιά `.8` → τώρα `.9`).

Από **Gaming-7**:

```bash
ping -c 2 192.168.1.9
# αν fail: στο EVO τρέξε hostname -I και χρησιμοποίησε το 192.168.1.x
ssh thomas-pashoulas@192.168.1.9
```

Στο **EVO** (οθόνη ή υπάρχον session): `hostname -I` → πρώτο `192.168.1.x`.

## Τι σημαίνει «ζωντανό project» (χωρίς οθόνη)

1. **Smoke:** `./scripts/evox3/09_smoke_check.sh` → **18 pass / 0 fail** (ή 10 στο παλιό `main`).
2. **Remote verify:** `./scripts/evox3/21_remote_verify.sh` → `REMOTE VERIFY OK`.
3. **Greek E2E (προαιρετικό):** `./scripts/evox3/13_remote_go_live.sh` → `indexed` + chat JSON.

## Γρήγορη ροή (από Gaming-7)

```bash
ssh "${EVOX3_SSH:-thomas-pashoulas@192.168.1.9}"
cd "$HOME/thoma"
git fetch origin '+refs/heads/main:refs/remotes/origin/main' || true
git checkout -B main origin/main
chmod +x scripts/evox3/*.sh
./scripts/evox3/21_remote_verify.sh
```

Μετά reboot / wipe / missing units (`Unit … not found`):

```bash
# Prefer HTTPS if git@github.com Permission denied:
git remote set-url origin https://github.com/thomaspas/thoma.git
git fetch origin
git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0 2>/dev/null \
  || git checkout -B main origin/main
chmod +x scripts/evox3/*.sh
./scripts/evox3/25_post_reboot_resume.sh
```

Χωρίς το PR branch (μόνο `main`):

```bash
./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh   # wait — no Ctrl+C during image pull
./scripts/evox3/run_all.sh                             # creates units 05/06/07 + brand
./scripts/evox3/21_remote_verify.sh
```

### Ήδη είσαι στον EVO-X3; (συχνό λάθος)

Αν το prompt είναι `thomas-pashoulas@thomas-pashoulas-EVO-X3` **μην** κάνεις `ssh` στο LAN IP — είναι SSH στον εαυτό σου (nested session). Τρέξε απευθείας:

```bash
cd "$HOME/thoma"
chmod +x scripts/evox3/*.sh
./scripts/evox3/22_operator_context_check.sh
./scripts/evox3/21_remote_verify.sh
```

`ssh-copy-id` από **Gaming-7** → EVO-X3, **όχι** από EVO-X3 → τον εαυτό του.

Πλήρες chat demo (αργό — Qwen 27B):

```bash
EVOX3_REMOTE_VERIFY_CHAT=1 ./scripts/evox3/21_remote_verify.sh
# ή απευθείας:
./scripts/evox3/13_remote_go_live.sh
```

## Bracketed paste (`^[[200~`)

Σε ορισμένα terminals το paste χαλάει `TOKEN=` / `export`. Χρησιμοποίησε demo scripts:

- `./scripts/evox3/17_demo_analytics.sh`
- `./scripts/evox3/18_demo_mcp.sh`
- `./scripts/evox3/13_remote_go_live.sh`

Ή απενεργοποίηση bracketed paste: `printf '\e[?2004l'`

## Πότε (σπάνια) χρειάζεται φυσική παρουσία

Μόνο αν **και** τα δύο:

- `10_relaunch_kiosk.sh` log: `Missing X server or $DISPLAY`
- `21_remote_verify.sh` fail στα process/HTML checks

Τότε: logged-in desktop session στο EVO-X3 ή VNC (εκτός scope αυτού του repo).

## Τι ελέγχει το `21_remote_verify.sh`

- Καλεί `09_smoke_check.sh` (baseline)
- HTML `:5173` — brand `ANGELICA`, όχι Register/Login
- `<title>` περιέχει ANGELICA
- `pgrep` chromium — `:5173` στα args, **όχι** `:8000`
- Προαιρετικά `13` αν `EVOX3_REMOTE_VERIFY_CHAT=1`

Τέλος: `=== REMOTE VERIFY OK — no physical visit needed ===`
