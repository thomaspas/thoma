# Cursor Desktop → EVO-X3 (Remote SSH + GBrain MCP)

Ο **Cursor Cloud agent δεν μπορεί** να ανοίξει SSH στο `192.168.1.8`. Αυτή η ροή είναι **Cursor Desktop στον operator PC** (Gaming-7, ίδιο LAN).

Το runtime του **ANGELICA** είναι GBrain Level 5 στο Mini PC. Scripts: [`ANGELICA_GBRAIN_LEVEL5.md`](ANGELICA_GBRAIN_LEVEL5.md). Μηχάνημα: [`EVOX3_MACHINE_AND_CHANGES.md`](EVOX3_MACHINE_AND_CHANGES.md). Nested SSH: [`REMOTE_OPERATOR_SSH.md`](REMOTE_OPERATOR_SSH.md).

## 1. SSH config (Gaming-7)

Αντέγραψε το Host block από [`ssh_config.evox3.example`](ssh_config.evox3.example) στο `~/.ssh/config` αν υπάρχει στο checkout· αλλιώς:

```
Host evox3
  HostName 192.168.1.8
  User thomas-pashoulas
  IdentityFile ~/.ssh/id_ed25519_evox3
  IdentitiesOnly yes
```

`ssh-copy-id` από **Gaming-7** → EVO-X3 μόνο (ποτέ από EVO-X3 προς τον εαυτό του).

## 2. Connect Cursor Desktop

1. Extension **Anysphere Remote SSH**.
2. Command Palette → `Remote-SSH: Connect to Host…` → `evox3`.
3. Άνοιγμα φακέλου: `~/thoma`. Το GBrain workspace είναι `~/gbrain-agent` (όχι μέσα στο `thoma`).
4. Το integrated terminal *είναι* το EVO-X3. **Μην** κάνεις `ssh 192.168.1.8` από εκεί.

```bash
cd "$HOME/thoma" && git pull --ff-only
chmod +x scripts/evox3/*.sh
./scripts/evox3/22_operator_context_check.sh
./scripts/evox3/26_retire_jinhua_kiosk.sh
./scripts/evox3/27_gbrain_angelica.sh
./scripts/evox3/28_gbrain_verify.sh
```

Paste το `28` στο Cloud chat.

## 3. GBrain MCP στο Cursor

Μετά το `27`, πρόσθεσε το snippet από [`mcp_cursor_gbrain.json.example`](mcp_cursor_gbrain.json.example) στα Cursor MCP settings **στο Remote SSH window** και κάνε restart MCP.

```json
{
  "mcpServers": {
    "gbrain": {
      "command": "gbrain",
      "args": ["serve"]
    }
  }
}
```

Απαιτεί `$HOME/.bun/bin` στο PATH του Cursor remote server. Αν το MCP δεν βρίσκει `gbrain`:

```bash
export PATH="$HOME/.bun/bin:$PATH"
which -a gbrain
gbrain --version
```

**Ποτέ** `npm install -g gbrain` (άλλο πακέτο που κάνει shadow το binary). Μόνο `bun install -g github:garrytan/gbrain`.

Το always-on systemd unit είναι `gbrain serve --http` στο `127.0.0.1:3131` (`angelica-gbrain.service`). Το Cursor MCP χρησιμοποιεί **stdio** `gbrain serve` — δεν αντικαθιστά το unit.

## 4. Troubleshooting

| Σύμπτωμα | Τι να κάνεις |
|----------|----------------|
| Prompt `thomas-pashoulas@thomas-pashoulas-EVO-X3` και `ssh 192.168.1.8` | Ήδη στον EVO-X3 — τρέξε τα scripts απευθείας. |
| `gbrain: command not found` στο MCP | PATH χωρίς bun· ξανατρέξε `27` ή πρόσθεσε `$HOME/.bun/bin`. |
| MCP τρέχει λάθος `gbrain` | `npm uninstall -g gbrain`· `28` δείχνει npm-shadow warning. |
| Unit inactive | `systemctl --user status angelica-gbrain.service`· ξανατρέξε `27`. |
| Cloud agent ζητά να «δει την οθόνη» | Αδύνατο από cloud. Paste `28_gbrain_verify.sh`. |
