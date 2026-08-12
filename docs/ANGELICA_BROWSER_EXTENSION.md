# ANGELICA Capture — Browser Extension

MV3 Chromium extension that sends web pages and text selections to the local ANGELICA API (`POST /documents/upload`).

## Prerequisites

- EVO-X3 LOCAL FULL stack running (API `:8000`, ingest pipeline).
- Chromium or Flatpak Chromium (regular browser profile — **not** the kiosk on `:5173`).

## Install (EVO-X3)

```bash
cd "$HOME/thoma"
chmod +x scripts/evox3/*.sh
./scripts/evox3/19_browser_extension.sh
```

This stages the extension at:

```
~/thoma/extensions/angelica-capture/build/chrome-mv3-prod
```

Script `19` also runs `20_patch_cors_extension.sh` on the Jinhua clone (adds `chrome-extension://` to FastAPI CORS). Skip with:

```bash
EVOX3_SKIP_CORS_PATCH=1 ./scripts/evox3/19_browser_extension.sh
```

Host permissions in `manifest.json` usually allow API calls without CORS; patch `20` is a safety net for popup/content flows.

## Load unpacked

1. Open `chrome://extensions` (or Chromium equivalent).
2. Enable **Developer mode**.
3. Click **Load unpacked**.
4. Select `~/thoma/extensions/angelica-capture/build/chrome-mv3-prod`.

## Configure

Click the extension icon → set:

| Field | Default |
|-------|---------|
| API URL | `http://127.0.0.1:8000` |
| Email | `ye@evox3.local` |
| Password | `evox3-local-12` |

Click **Save**.

## Capture

- **Popup:** Capture page — uploads title, URL, and main article/body text as markdown.
- **Context menu:** Right-click → **Capture page to ANGELICA** or **Capture selection to ANGELICA**.

On success you get a notification with `document_id`. Ingest runs in the background (same as UI upload). Poll with:

```bash
./scripts/evox3/15_diagnose_ingest.sh <document_id>
```

## curl smoke (no browser)

```bash
./scripts/evox3/19_demo_capture.sh
```

## Troubleshooting

### Upload fails with login HTTP 500

Postgres may be down after reboot. Fix:

```bash
./scripts/evox3/02_ensure_jinhua_clone_and_docker.sh
./scripts/evox3/09_smoke_check.sh
```

### CORS / blocked by client

Re-run `./scripts/evox3/20_patch_cors_extension.sh` and restart API:

```bash
systemctl --user restart evox3-jinhua-api.service
```

### Extension not in smoke

Smoke checks extension only after `19` has run (marker `.evox3-built`). Re-run `19` if build dir is missing.

## Source layout

```
extensions/angelica-capture/
  manifest.json      # MV3 manifest + host_permissions
  background.js        # context menus, capture, upload
  popup.html / popup.js
  lib/api.js           # login + upload helpers
  assets/icon.png
```

No npm build step — `19` copies source to `build/chrome-mv3-prod/` for Load unpacked.
