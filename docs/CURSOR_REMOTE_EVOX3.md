# Cursor Desktop → EVO-X3 (Remote SSH + οθόνη)

Ο **Cursor Cloud agent δεν μπορεί** να ανοίξει SSH στο `192.168.1.9` ούτε να δει την οθόνη του EVO-X3 (ιδιωτικό LAN). Αυτή η ροή είναι **Cursor Desktop στον operator PC** (Gaming-7, ίδιο δίκτυο).

Το Cursor δεν έχει ενσωματωμένο TeamViewer. Μέσα στο Cursor δουλεύουν:

1. **Remote SSH** — terminal, αρχεία και agent τρέχουν *πάνω στο EVO-X3*.
2. **Simple Browser** — προεπισκόπηση της φυσικής οθόνης (`:5174`, opt-in) και/ή το ANGELICA UI (`:5173`).

RDP/VNC μένουν εκτός — ανοίγουν σε άλλο παράθυρο, όχι μέσα στο Cursor.

## 1. SSH config (Gaming-7)

Αντέγραψε το Host block από [`ssh_config.evox3.example`](ssh_config.evox3.example) στο `~/.ssh/config`:

```
Host evox3
  HostName 192.168.1.9
  User thomas-pashoulas
  IdentityFile ~/.ssh/id_ed25519_evox3
  IdentitiesOnly yes
```

Wi‑Fi DHCP μπορεί να αλλάξει το IP — στο EVO: `hostname -I`, μετά ενημέρωσε `HostName` ή `EVOX3_SSH`.

Το κλειδί είναι το ίδιο που χρησιμοποιεί το `scripts/operator/auto_close_angelica.sh`. Αν δεν υπάρχει ακόμα:

```bash
# FROM Gaming-7 only — never from EVO-X3 to 192.168.1.9
ssh-copy-id -i ~/.ssh/id_ed25519_evox3.pub thomas-pashoulas@192.168.1.9
```

Δες και [`REMOTE_OPERATOR_SSH.md`](REMOTE_OPERATOR_SSH.md) (nested SSH / already-on-EVO-X3).

## 2. Connect Cursor Desktop + recover ANGELICA

1. Εγκατάσταση extension **Anysphere Remote SSH** (όχι Microsoft Remote-SSH).
2. Command Palette → `Remote-SSH: Connect to Host…` → `evox3` (ή `thomas-pashoulas@192.168.1.9`).
3. Άνοιγμα φακέλου: `~/thoma` (operator scripts). Προαιρετικά δεύτερο παράθυρο: `~/ai_apps/IncubativeSecondBrain` (runtime).
4. Το integrated terminal *είναι* το EVO-X3. **Μην** κάνεις `ssh thomas-pashoulas@192.168.1.9` από εκεί (nested session).

```bash
cd "$HOME/thoma"
git remote set-url origin https://github.com/thomaspas/thoma.git
git fetch origin cursor/evox3-ip-dhcp-c1c0
git checkout -B cursor/evox3-ip-dhcp-c1c0 origin/cursor/evox3-ip-dhcp-c1c0
chmod +x scripts/evox3/*.sh scripts/operator/*.sh

# 10s paste-friendly dump (στείλε το output στο Cloud agent chat)
curl -fsSL https://raw.githubusercontent.com/thomaspas/thoma/cursor/evox3-ip-dhcp-c1c0/scripts/operator/remote_status_dump.sh | bash

# Αν 05 κόλλησε στο bge / λείπουν API+UI units:
./scripts/evox3/26_resume_after_bge.sh
# ή: curl -fsSL .../remote_resume_after_bge.sh | bash
```

Επιτυχία: `REMOTE VERIFY OK — no physical visit needed` — paste στο Cloud agent.

Γρήγορη κάρτα: [`OPERATOR_RECOVER_NOW.md`](OPERATOR_RECOVER_NOW.md).

## 3. Οθόνη EVO-X3 μέσα στο Cursor (προαιρετικό)

Αν υπάρχει `scripts/evox3/27_remote_screen_preview.sh` στο remote terminal:

```bash
./scripts/evox3/27_remote_screen_preview.sh
```

Μετά: Command Palette → `Simple Browser: Show` → `http://127.0.0.1:5174/` (οθόνη) ή `http://127.0.0.1:5173/` (UI).

Σταμάτημα: `./scripts/evox3/27_remote_screen_preview.sh stop`

Χωρίς Remote-SSH (μένεις local στο Gaming-7), tunnel:

```bash
ssh -N -L 5174:127.0.0.1:5174 -L 5173:127.0.0.1:5173 evox3
```

## 4. Troubleshooting

| Σύμπτωμα | Τι να κάνεις |
|----------|----------------|
| Prompt `…EVO-X3` και `ssh 192.168.1.9` | Ήδη στον EVO — τρέξε scripts απευθείας. |
| `Permission denied` | `ssh-copy-id` από Gaming-7 με `id_ed25519_evox3`. |
| `No route to host` | DHCP άλλαξε IP — `hostname -I` στο EVO. |
| Cloud agent ζητά να «δει την οθόνη» | Αδύνατο από cloud. Paste `21` / status dump / resume log. |
