# HANDOFF — 2026-08-12 Project state save

**BLUF:** ANGELICA on EVO-X3 is operational and healthy at the stack level (`09_smoke_check.sh` = **18 pass / 0 fail**). The open milestone is still **remote kiosk verify from SSH** plus landing [PR #8](https://github.com/thomaspas/thoma/pull/8). Nothing should be resumed from the Warden/NEBULA track.

## Project identity

- Repo: [thomaspas/thoma](https://github.com/thomaspas/thoma)
- Branch to continue: `cursor/land-angelica-stack-8dd2`
- Active PR: [#8](https://github.com/thomaspas/thoma/pull/8)
- Runtime machine: EVO-X3 (`thomas-pashoulas@192.168.1.8`)
- Operator machine: Gaming-7 (`thomas1821-Z170X-Gaming-7`)

## What is done

- LOCAL FULL stack works on EVO-X3
- ANGELICA branding is in place on the web UI
- Neo4j graph analytics endpoints are in place
- MCP server and browser extension workstreams are done
- `09_smoke_check.sh` last known result: **18 pass / 0 fail**
- Remote HTML on `:5173` showed ANGELICA and no Login/AuthScreen

## What is not done yet

- `21_remote_verify.sh` last known result: **5 pass / 1 fail**
- Remaining fail: `browser process missing :5173`
- PR #8 is still open
- Local Gaming-7 work has **not** been fully pushed to origin yet

## Current local state on Gaming-7

Local commits ahead of `origin/cursor/land-angelica-stack-8dd2`:

- `05dc51a` — `Fix kiosk relaunch from SSH for remote verify.`
- `6885ba3` — `Add auto_close_angelica.sh operator automation script.`

Also present locally but not committed yet:

- `scripts/operator/auto_close_angelica.sh` has newer GH_TOKEN/debug edits after `6885ba3`

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
2. Do not run `ssh thomas-pashoulas@192.168.1.8` from inside EVO-X3 (nested SSH to self).
3. Do not mix this project with `~/Λήψεις/ΑΝΑΦΟΡΑ_ΠΛΗΡΗΣ.md` or the Warden/NEBULA track.
4. Do not paste shell prompts back into the terminal as commands.
5. Do not paste the actual GitHub token into chat.

## Resume plan

### Path A — preferred

Run from Gaming-7:

```bash
export GH_TOKEN='ghp_...'
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

The only meaningful blocker is the final operator flow:

1. push local work from Gaming-7
2. get `REMOTE VERIFY OK`
3. update chronicle closeout
4. merge PR #8

## Copy-paste prompt for a new Cursor chat

```text
Continue the `thoma` / ANGELICA project on branch `cursor/land-angelica-stack-8dd2`.

Read:
- docs/HANDOFF_2026-08-12_PROJECT_STATE_SAVE.md
- docs/HANDOFF_2026-08-12_REMOTE_VERIFY.md
- docs/SESSION_CHRONICLE_ANGELICA.md

Current state:
- EVO-X3 stack healthy: smoke 18/0
- last remote verify: 5/1 fail, only kiosk :5173
- PR #8 still open
- local Gaming-7 commits ahead of origin: 05dc51a and 6885ba3
- local uncommitted edits also exist in scripts/operator/auto_close_angelica.sh

Goal:
- preserve all current work
- finish remote verify
- then close PR #8
```
