# Remote operator — SSH only

Ο operator (Thomas) τρέχει **όλες** τις εντολές από **άλλο PC** μέσω SSH — όχι δίπλα στον EVO-X3.

| Στοιχείο | Τιμή |
|----------|------|
| EVO-X3 | `thomas-pashoulas@192.168.1.8` (άλλο δωμάτιο) |
| Operator PC | Gaming-7 (ή άλλο) — μόνο terminal + paste output |
| Kiosk | Ανοίγει αυτόματα στον EVO-X3 (`:5173`) — **δεν** χρειάζεται επίσκεψη |

## Κανόνας για agents

- **Μην** ζητάς «πήγαινε στον EVO-X3 / κοίτα την οθόνη / δες το kiosk» ως πρώτο βήμα.
- **Ναι:** SSH εντολές + paste του script output στο chat.
- Cloud agent: δεν έχει SSH — ο χρήστης κάνει paste από το EVO-X3 terminal.

## Τι σημαίνει «ζωντανό project» (χωρίς οθόνη)

1. **Smoke:** `./scripts/evox3/09_smoke_check.sh` → **18 pass / 0 fail** (ή 10 στο παλιό `main`).
2. **Remote verify:** `./scripts/evox3/21_remote_verify.sh` → `REMOTE VERIFY OK`.
3. **Greek E2E (προαιρετικό):** `./scripts/evox3/13_remote_go_live.sh` → `indexed` + chat JSON.

## Γρήγορη ροή (από Gaming-7)

```bash
ssh thomas-pashoulas@192.168.1.8
cd "$HOME/thoma"
git fetch origin '+refs/heads/cursor/land-angelica-stack-8dd2:refs/remotes/origin/cursor/land-angelica-stack-8dd2'
git checkout -B cursor/land-angelica-stack-8dd2 origin/cursor/land-angelica-stack-8dd2
chmod +x scripts/evox3/*.sh
./scripts/evox3/21_remote_verify.sh
```

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
