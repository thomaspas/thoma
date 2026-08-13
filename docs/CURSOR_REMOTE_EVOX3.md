# Cursor Desktop → EVO-X3 (Remote SSH + οθόνη)

Ο **Cursor Cloud agent δεν μπορεί** να ανοίξει SSH στο `192.168.1.8` ούτε να δει την οθόνη του EVO-X3 (ιδιωτικό LAN). Αυτή η ροή είναι **Cursor Desktop στον operator PC** (Gaming-7, ίδιο δίκτυο).

Το Cursor δεν έχει ενσωματωμένο TeamViewer. Μέσα στο Cursor δουλεύουν:

1. **Remote SSH** — terminal, αρχεία και agent τρέχουν *πάνω στο EVO-X3*.
2. **Simple Browser** — προεπισκόπηση της φυσικής οθόνης (`:5174`, screenshot κάθε ~2s) και/ή το ANGELICA UI (`:5173`).

RDP/VNC μένουν εκτός — ανοίγουν σε άλλο παράθυρο, όχι μέσα στο Cursor.

## 1. SSH config (Gaming-7)

Αντέγραψε το Host block από [`ssh_config.evox3.example`](ssh_config.evox3.example) στο `~/.ssh/config`:

```
Host evox3
  HostName 192.168.1.8
  User thomas-pashoulas
  IdentityFile ~/.ssh/id_ed25519_evox3
  IdentitiesOnly yes
```

Το κλειδί είναι το ίδιο που χρησιμοποιεί το `scripts/operator/auto_close_angelica.sh`. Αν δεν υπάρχει ακόμα:

```bash
# FROM Gaming-7 only — never from EVO-X3 to 192.168.1.8
ssh-copy-id -i ~/.ssh/id_ed25519_evox3.pub thomas-pashoulas@192.168.1.8
```

Δες και [`REMOTE_OPERATOR_SSH.md`](REMOTE_OPERATOR_SSH.md) (nested SSH / already-on-EVO-X3).

## 2. Connect Cursor Desktop

1. Εγκατάσταση extension **Anysphere Remote SSH** (όχι Microsoft Remote-SSH).
2. Command Palette → `Remote-SSH: Connect to Host…` → `evox3` (ή `thomas-pashoulas@192.168.1.8`).
3. Άνοιγμα φακέλου: `~/thoma` (operator scripts). Προαιρετικά δεύτερο παράθυρο: `~/ai_apps/IncubativeSecondBrain` (runtime).
4. Το integrated terminal *είναι* το EVO-X3. **Μην** κάνεις `ssh thomas-pashoulas@192.168.1.8` από εκεί (nested session).

```bash
cd "$HOME/thoma"
chmod +x scripts/evox3/*.sh
./scripts/evox3/22_operator_context_check.sh
./scripts/evox3/21_remote_verify.sh
```

## 3. Οθόνη EVO-X3 μέσα στο Cursor

Στο **remote** terminal (EVO-X3):

```bash
./scripts/evox3/25_remote_screen_preview.sh
```

Μετά:

- Command Palette → `Simple Browser: Show` → `http://127.0.0.1:5174/` (φυσική οθόνη / kiosk).
- Προαιρετικά `http://127.0.0.1:5173/` (ANGELICA UI χωρίς desktop chrome).

Σταμάτημα:

```bash
./scripts/evox3/25_remote_screen_preview.sh stop
```

Το preview ακούει **μόνο** `127.0.0.1:5174` (όχι bind στο LAN).

### Χωρίς Remote-SSH (μένεις local στο Gaming-7)

Ξεκίνα το preview στο EVO-X3 (ένα SSH session), μετά tunnel από Gaming-7:

```bash
ssh -N -L 5174:127.0.0.1:5174 -L 5173:127.0.0.1:5173 evox3
```

Simple Browser στα ίδια URLs στο **local** Cursor.

## 4. Troubleshooting

| Σύμπτωμα | Τι να κάνεις |
|----------|----------------|
| Prompt `thomas-pashoulas@thomas-pashoulas-EVO-X3` και `ssh 192.168.1.8` | Ήδη στον EVO-X3 — τρέξε τα scripts απευθείας. |
| `Permission denied` / repeated password | `ssh-copy-id` από Gaming-7 με `IdentityFile ~/.ssh/id_ed25519_evox3`. |
| Remote-SSH timeout installing server | Anysphere extension· στο EVO-X3: `pkill -f .cursor-server` μόνο αν κόλλησε install. |
| Preview: `No logged-in desktop session` / capture fail | Ίδιο constraint με το kiosk: GNOME session logged in στο EVO-X3. `ls /run/user/$(id -u)/wayland-*` μετά `10_relaunch_kiosk.sh`. |
| Simple Browser κενό στο local Cursor | Δεν είσαι Remote-SSH — χρειάζεσαι το SSH tunnel `:5174`. |
| Cloud agent ζητά να «δει την οθόνη» | Αδύνατο από cloud. Paste `21_remote_verify.sh` / `25` status output. |

Προϋπόθεση kiosk: logged-in desktop στο EVO-X3 (`DISPLAY` / `WAYLAND_DISPLAY`). Το `25` ξαναχρησιμοποιεί το `setup_local_graphical_env()` από `_lib.sh`.
