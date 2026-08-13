# Cursor Desktop — Remote SSH + live ANGELICA view

Ο operator (Thomas) κάθεται στο **Gaming-7**. Το runtime είναι το **EVO-X3** (άλλο δωμάτιο, GNOME). Αυτός ο οδηγός συνδέει **Cursor Desktop** στο EVO ώστε:

- το terminal του Cursor να είναι το terminal του EVO
- το **Agent** να διαβάζει εντολές/output χωρίς paste
- να βλέπεις live το ANGELICA UI (`:5173`) μέσα στο Cursor
- να βλέπεις την **πραγματική οθόνη** GNOME/kiosk μέσω GNOME Remote Desktop (RDP)

**Cloud Agent** (`cursor.com/agents` / αυτό το cloud chat) **δεν** βλέπει `192.168.1.8`. Μην περιμένεις Agent του EVO μέσα σε cloud/Plan thread.

## Δύο εικόνες

| Τι βλέπεις | Πού | Live; |
|------------|-----|-------|
| Ίδιο ANGELICA UI (`:5173`) | Cursor Simple Browser (Remote SSH port forward) | Ναι |
| Ακριβώς η οθόνη GNOME/kiosk | GNOME Remote Desktop (RDP) — Remmina / Connections | Ναι |
| Στιγμιότυπο μέσα στο Cursor | `./scripts/evox3/25_kiosk_snapshot.sh` | Όχι (PNG) |

Το Vite είναι δεμένο σε `127.0.0.1:5173` — **όχι** `http://192.168.1.8:5173`. Το Remote SSH κάνει forward το localhost. Μην αλλάζεις `--host 0.0.0.0`.

## 1) SSH config (Gaming-7)

`~/.ssh/config`:

```sshconfig
Host evo-x3
    HostName 192.168.1.8
    User thomas-pashoulas
    IdentityFile ~/.ssh/id_ed25519_evox3
    IdentitiesOnly yes
```

Δοκιμή:

```bash
ssh evo-x3 'hostname; echo ok'
```

`ssh-copy-id` μόνο από Gaming-7 → EVO. Αν το prompt είναι ήδη `thomas-pashoulas-EVO-X3`, **μην** ξανακάνεις `ssh 192.168.1.8` (nested SSH).

## 2) Cursor Desktop → EVO (εδώ εμφανίζεται το Agent)

1. Cursor Desktop στο **Gaming-7** (όχι Cloud).
2. `Ctrl+Shift+P` → **Remote-SSH: Connect to Host…** → `evo-x3`
   (ή `thomas-pashoulas@192.168.1.8`).
3. Άνοιξε φάκελο `/home/thomas-pashoulas/thoma`.
4. Πάνω αριστερά: **SSH: evo-x3** (ή hostname EVO-X3).
5. **Νέο chat σε ΕΚΕΙΝΟ το παράθυρο** (`Ctrl+L`) → mode **Agent** (όχι Ask, όχι Plan, όχι Cloud).

Αν λείπει το Connect to Host: εγκατάσταση extension **Anysphere Remote SSH**. Αφαίρεσε το παλιό Microsoft Remote-SSH αν συγκρούεται.

Εκεί:

- Terminal = shell στον EVO
- Agent διαβάζει filesystem + command output
- `./scripts/evox3/22_operator_context_check.sh` πρέπει να πει ότι είσαι στον EVO

```bash
cd ~/thoma
chmod +x scripts/evox3/*.sh
./scripts/evox3/22_operator_context_check.sh
./scripts/evox3/21_remote_verify.sh
```

## 3) Live UI μέσα στο Cursor (`:5173`)

Στο Remote SSH παράθυρο:

1. Panel **Ports** → Forward **5173** (συχνά αυτόματο).
2. Simple Browser (ή τοπικός browser) → `http://127.0.0.1:5173`.

Αυτό είναι το **ίδιο** ANGELICA με το kiosk (όχι τα pixels του monitor). Το kiosk στο EVO συνεχίζει κανονικά. Ποτέ kiosk στο `:8000`.

## 4) Live φυσική οθόνη (GNOME RDP)

Το EVO τρέχει GNOME/Wayland. Δεν στήνουμε TightVNC.

Στο **EVO** (Cursor SSH terminal):

```bash
cd ~/thoma
./scripts/evox3/26_gnome_remote_desktop.sh
```

Από **Gaming-7**: Remmina ή GNOME Connections → RDP `192.168.1.8:3389`. User/password στο `~/.config/evox3/grd-rdp.env` στον EVO (chmod 600, όχι git).

Αυτό δείχνει το kiosk όπως είναι στο άλλο δωμάτιο. Τρέχει **δίπλα** στο Cursor (όχι μέσα στο editor).

## 5) Στιγμιότυπο μέσα στο Cursor

```bash
cd ~/thoma
./scripts/evox3/25_kiosk_snapshot.sh
```

Άνοιξε `/tmp/angelica-kiosk.png` στο Remote SSH παράθυρο.

## Cloud vs Desktop

| Session | Βλέπει EVO LAN; | Agent τρέχει εντολές στον EVO; |
|---------|-----------------|--------------------------------|
| Cloud Agent | Όχι | Όχι — paste output |
| Desktop + Remote SSH | Ναι | Ναι, στο SSH παράθυρο |

Κανόνας: μην ζητάς επίσκεψη στο άλλο δωμάτιο. Verify: `21_remote_verify.sh`. Οθόνη: Simple Browser / `25` / GNOME RDP (`26`).
