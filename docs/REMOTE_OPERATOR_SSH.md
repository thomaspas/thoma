# Remote operator — SSH only

Ο operator (Thomas) τρέχει **όλες** τις εντολές από **άλλο PC** μέσω SSH — όχι δίπλα στον EVO-X3.

| Στοιχείο | Τιμή |
|----------|------|
| EVO-X3 | `thomas-pashoulas@192.168.1.8` (άλλο δωμάτιο) |
| Operator PC | Gaming-7 (ή άλλο) — μόνο terminal + paste output |
| ANGELICA | GBrain Level 5 στο EVO-X3 — **δεν** χρειάζεται επίσκεψη οθόνης |

## Κανόνας για agents

- **Μην** ζητάς «πήγαινε στον EVO-X3 / κοίτα την οθόνη / δες το kiosk» ως πρώτο βήμα.
- **Ναι:** SSH εντολές + paste του script output στο chat.
- Cloud agent: δεν έχει SSH — ο χρήστης κάνει paste από το EVO-X3 terminal.

## Τι σημαίνει «ζωντανό project» (χωρίς οθόνη)

1. **GBrain verify:** `./scripts/evox3/28_gbrain_verify.sh` → paste output (τρέχον).
2. Historical Jinhua (retired): `09_smoke_check.sh` / `21_remote_verify.sh` — μην τα περιμένεις green μετά το `26`.

## Γρήγορη ροή (από Gaming-7)

```bash
ssh thomas-pashoulas@192.168.1.8
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
./scripts/evox3/28_gbrain_verify.sh
```

### Ήδη είσαι στον EVO-X3; (συχνό λάθος)

Αν το prompt είναι `thomas-pashoulas@thomas-pashoulas-EVO-X3` **μην** κάνεις `ssh thomas-pashoulas@192.168.1.8` — είναι SSH στον εαυτό σου (nested session). Τρέξε απευθείας:

```bash
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
./scripts/evox3/22_operator_context_check.sh
./scripts/evox3/28_gbrain_verify.sh
```

`ssh-copy-id` από **Gaming-7** → EVO-X3, **όχι** από EVO-X3 → `192.168.1.8` (ίδιο μηχάνημα).

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
