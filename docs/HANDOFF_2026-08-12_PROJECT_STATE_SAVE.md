# HANDOFF — 2026-08-12 Project state save

**BLUF:** ANGELICA on EVO-X3 is operational and healthy at the stack level (`09_smoke_check.sh` = **18 pass / 0 fail**). The open milestone is still **remote kiosk verify from SSH** plus landing [PR #8](https://github.com/thomaspas/thoma/pull/8). Nothing should be resumed from the Warden/NEBULA track.

## Project identity

- Repo: [thomaspas/thoma](https://github.com/thomaspas/thoma)
- Branch to continue: `cursor/land-angelica-stack-8dd2`
- Active PR: [#8](https://github.com/thomaspas/thoma/pull/8)
- Runtime machine: EVO-X3 (`thomas-pashoulas@192.168.1.9`, Wi‑Fi DHCP — was `.8`)
- Operator machine: Gaming-7 (`thomas1821-Z170X-Gaming-7`)

## What is done

- LOCAL FULL stack works on EVO-X3
- ANGELICA branding is in place on the web UI
- Neo4j graph analytics endpoints are in place
- MCP server and browser extension workstreams are done
- `09_smoke_check.sh` last known result: **18 pass / 0 fail**
- Remote HTML on `:5173` showed ANGELICA and no Login/AuthScreen
- `auto_close_angelica.sh` validates `GH_TOKEN` via `gh api user`
- `auto_close_angelica.sh` now uses a single canonical HTTPS push path with `x-access-token`

## What is not done yet

- `21_remote_verify.sh` last known result: **5 pass / 1 fail**
- Remaining fail: `browser process missing :5173`
- PR #8 is still open
- Local Gaming-7 work has **not** been fully pushed to origin yet

## Current local state on Gaming-7

Local commits ahead of `origin/cursor/land-angelica-stack-8dd2`:

- `05dc51a` — `Fix kiosk relaunch from SSH for remote verify.`
- `6885ba3` — `Add auto_close_angelica.sh operator automation script.`
- `bf0c930` — `Save project state handoff + fix GH_TOKEN auth in auto_close.`
- `3cc4b9c` — `fix(operator): git push via x-access-token when GH_TOKEN is set`
- `20aca1f` — `fix(operator): harden GH_TOKEN push with credential bypass and debug logs`
- `6d57755` — `fix(operator): add gh-setup-git fallback and stricter GH_TOKEN checks`
- `fd28029` — `fix(operator): repair debug logger JSON boolean parsing`
- `a764cff` — `fix(operator): avoid bash brace expansion in _dbg default arg`
- *(next local commit)* — simplify `auto_close_angelica.sh` and align docs with the real operator flow

## Important files

- `docs/SESSION_CHRONICLE_ANGELICA.md`
- `docs/HANDOFF_2026-08-12_REMOTE_VERIFY.md`
- `docs/REMOTE_OPERATOR_SSH.md`
- `scripts/evox3/08_autostart_desktop.sh`
- `scripts/evox3/10_relaunch_kiosk.sh`
- `scripts/evox3/21_remote_verify.sh`
- `scripts/evox3/22_operator_context_check.sh`
- `scripts/evox3/23_sync_verify_fix_to_evox3.sh`
- `scripts/operator/auto_close_angelica.sh`

## Key lessons / mistakes to avoid

1. Do not run operator automation on EVO-X3 when the script exists only on Gaming-7.
2. Do not run `ssh` to the EVO LAN IP from inside EVO-X3 (nested SSH to self).
3. Do not mix this project with `~/Λήψεις/ΑΝΑΦΟΡΑ_ΠΛΗΡΗΣ.md` or the Warden/NEBULA track.
4. Do not paste shell prompts back into the terminal as commands.
5. Do not paste the actual GitHub token into chat.

## Resume plan

### Path A — preferred

Run from Gaming-7:

```bash
export GH_TOKEN='your_real_pat_from_github_settings_tokens'
export PATH="$HOME/.local/bin:$PATH"
cd ~/thoma
./scripts/operator/auto_close_angelica.sh
```

Expected responsibilities of the script:

- validate `GH_TOKEN`
- push the local branch to GitHub
- bootstrap SSH to EVO-X3 if needed
- run EVO-X3 verify
- on success, update chronicle and merge PR #8

### Path B — manual EVO-X3 verify

If continuing manually on EVO-X3 after the branch is pushed:

```bash
cd ~/thoma
git fetch origin
git checkout cursor/land-angelica-stack-8dd2
git pull origin cursor/land-angelica-stack-8dd2
chmod +x scripts/evox3/*.sh
./scripts/evox3/08_autostart_desktop.sh
./scripts/evox3/21_remote_verify.sh
```

If kiosk still fails:

```bash
cd ~/thoma
./scripts/evox3/22_operator_context_check.sh
./scripts/evox3/10_relaunch_kiosk.sh
tail -40 /tmp/evox3-jinhua-kiosk.log
./scripts/evox3/21_remote_verify.sh
```

## Current blocker

**Previous failure (2026-08-12):**

```
[+] GitHub token OK (user: thomaspas)
[*] Pushing 3 commit(s) to origin/cursor/land-angelica-stack-8dd2
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

**Root cause:** the original operator script authenticated `gh api`, but `git push` still fell back to an interactive HTTPS credential prompt. Later retries also mixed in placeholder tokens like `ghp_...`, which looked like real values but were not valid PATs.

**Fix applied:** `auto_close_angelica.sh` now keeps one canonical push flow: validate `GH_TOKEN` with `gh api user`, then push over HTTPS with `x-access-token`.

**Next operator step:** run `auto_close_angelica.sh` from Gaming-7 with a real GitHub PAT that has `repo` scope.

## Copy-paste prompt for a new Cursor chat

```text
Continue ANGELICA closeout on thomaspas/thoma, branch cursor/land-angelica-stack-8dd2.

Read first:
- docs/HANDOFF_2026-08-12_PROJECT_STATE_SAVE.md
- docs/HANDOFF_2026-08-12_REMOTE_VERIFY.md
- docs/SESSION_CHRONICLE_ANGELICA.md

State:
- EVO-X3 stack: smoke 18/0 OK
- Remote verify last: 5/1 (only kiosk :5173 browser process)
- PR #8 open
- Gaming-7: local branch is ahead of origin with operator-flow fixes and cleanup
- The only remaining blocker is running the cleaned operator script with a real PAT from Gaming-7

Goal (Gaming-7 only):
export GH_TOKEN='your_real_pat_from_github_settings_tokens'
export PATH="$HOME/.local/bin:$PATH"
cd ~/thoma && ./scripts/operator/auto_close_angelica.sh

Success = REMOTE VERIFY OK (6/0) + PR #8 merged.
Do NOT resume Warden/NEBULA track in ~/Λήψεις/.
```
