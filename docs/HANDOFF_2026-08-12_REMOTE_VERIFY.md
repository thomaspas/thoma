# HANDOFF — 2026-08-12 Remote verify / kiosk SSH

**BLUF:** Stack is live (smoke **18/0**). Only gap: Chromium kiosk not on `:5173` when verifying from SSH. Patches committed locally on `cursor/land-angelica-stack-8dd2` (**ahead of origin** — run push below) — **push from Gaming-7**, then `git pull` on EVO-X3 and run `21_remote_verify.sh`.

### Gaming-7 — push (required before EVO-X3 pull)

```bash
cd ~/thoma && git push origin cursor/land-angelica-stack-8dd2
```

## Machines

| Role | Host | SSH |
|------|------|-----|
| Operator | Gaming-7 (`thomas1821-Z170X-Gaming-7`) | — |
| Runtime | EVO-X3 (`thomas-pashoulas-EVO-X3`) | `thomas-pashoulas@192.168.1.8` |

## Repo

- GitHub: [thomaspas/thoma](https://github.com/thomaspas/thoma)
- Branch: `cursor/land-angelica-stack-8dd2`
- PR: [#8](https://github.com/thomaspas/thoma/pull/8)
- Path on EVO-X3: `~/thoma`

## Last verified state (user paste, EVO-X3)

```
09_smoke_check.sh     → 18 pass / 0 fail
21_remote_verify.sh   → 5 pass / 1 fail
Fail: browser process missing :5173
HTML :5173            → ANGELICA, no Login/AuthScreen
Pi-hole               → NOT related (all local HTTP OK)
```

## Common mistakes

1. **Already on EVO-X3** — do NOT `ssh thomas-pashoulas@192.168.1.8` (nested SSH to self).
2. **ssh-copy-id** — from Gaming-7 → EVO-X3 only, not EVO-X3 → `192.168.1.8`.
3. **Do not ask** operator to visit the other room / look at the screen — SSH + paste only.

See also: [`REMOTE_OPERATOR_SSH.md`](REMOTE_OPERATOR_SSH.md), [`SESSION_CHRONICLE_ANGELICA.md`](SESSION_CHRONICLE_ANGELICA.md).

## Patched files (Gaming-7 `~/thoma`, sync before verify)

| File | Change |
|------|--------|
| `scripts/evox3/_lib.sh` | `import_graphical_env_from_desktop_session()`, `/proc` kiosk port scan |
| `scripts/evox3/10_relaunch_kiosk.sh` | `systemd-run` + `gtk-launch` fallback |
| `scripts/evox3/21_remote_verify.sh` | auto-relaunch + 45s wait |
| `scripts/evox3/08_autostart_desktop.sh` | wrapper `exit 1` if no browser |
| `scripts/evox3/22_operator_context_check.sh` | operator context warnings |
| `scripts/evox3/23_sync_verify_fix_to_evox3.sh` | scp helper Gaming-7 → EVO-X3 |
| `docs/REMOTE_OPERATOR_SSH.md` | "already on EVO-X3" section |

## Sync Gaming-7 → EVO-X3

From **Gaming-7** (if SSH key to EVO-X3 works):

```bash
chmod +x ~/thoma/scripts/evox3/23_sync_verify_fix_to_evox3.sh
~/thoma/scripts/evox3/23_sync_verify_fix_to_evox3.sh
```

Or manual scp of the files listed above to `~/thoma/` on EVO-X3.

## Verify on EVO-X3 (SSH terminal)

**After sync:**

```bash
cd ~/thoma && chmod +x scripts/evox3/*.sh && ./scripts/evox3/08_autostart_desktop.sh && ./scripts/evox3/21_remote_verify.sh
```

**Without sync (origin branch only):**

```bash
cd ~/thoma && ./scripts/evox3/10_relaunch_kiosk.sh && ./scripts/evox3/21_remote_verify.sh
```

**Success:** `=== REMOTE VERIFY OK — no physical visit needed ===` and `6 pass / 0 fail` (or 7 with chat E2E).

**Optional Greek chat E2E (slow):**

```bash
EVOX3_REMOTE_VERIFY_CHAT=1 ./scripts/evox3/21_remote_verify.sh
# or: ./scripts/evox3/13_remote_go_live.sh
```

## Troubleshooting

```bash
tail -40 /tmp/evox3-jinhua-kiosk.log
cat /tmp/thoma-debug-f7f922.ndjson   # if debug run
./scripts/evox3/22_operator_context_check.sh
```

If kiosk log shows `Missing X server` or `$DISPLAY`: desktop session must be logged in on EVO-X3; re-run `10_relaunch_kiosk.sh` from SSH.

## Prompt for new Cursor chat (copy-paste)

```
Συνεχίζουμε το thoma / ANGELICA στο EVO-X3.

Context: docs/HANDOFF_2026-08-12_REMOTE_VERIFY.md + docs/REMOTE_OPERATOR_SSH.md
Branch: cursor/land-angelica-stack-8dd2 (PR #8)
Operator: SSH από Gaming-7 στο thomas-pashoulas@192.168.1.8

Τελευταίο verify: smoke 18/0 OK, 21_remote_verify 5 pass / 1 fail (kiosk :5173).
Έχω ανοιχτό SSH terminal στον EVO-X3.

Στόχος: REMOTE VERIFY OK (6 pass / 0 fail) χωρίς επίσκεψη στο άλλο δωμάτιο.
Μην ζητάς οθόνη — μόνο εντολές SSH + paste output.
```

## NOT this project

- Warden/NEBULA Second Brain (`~/Λήψεις/ΑΝΑΦΟΡΑ_ΠΛΗΡΗΣ.md`) — older parallel track.
