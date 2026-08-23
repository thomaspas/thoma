#!/usr/bin/env python3
"""HTTP screen preview for Cursor Simple Browser. Bind 127.0.0.1 only."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = os.environ.get("EVOX3_SCREEN_PREVIEW_BIND", "127.0.0.1")
PORT = int(os.environ.get("EVOX3_SCREEN_PREVIEW_PORT", "5174"))
STATE_DIR = Path(os.environ.get("EVOX3_SCREEN_PREVIEW_DIR", "/tmp/evox3-screen-preview"))
PNG_PATH = STATE_DIR / "screen.png"
REFRESH_MS = int(os.environ.get("EVOX3_SCREEN_PREVIEW_REFRESH_MS", "2000"))

_lock = threading.Lock()
_last_method = "none"
_last_error = ""
_last_ok_ts = 0.0

INDEX_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>EVO-X3 screen preview</title>
  <meta http-equiv="refresh" content="{refresh_sec}">
  <style>
    html, body {{ margin: 0; background: #111; color: #ddd; font-family: sans-serif; }}
    img {{ max-width: 100%; height: auto; display: block; }}
    .bar {{ padding: 8px 12px; font-size: 13px; background: #1c1c1c; }}
  </style>
</head>
<body>
  <div class="bar">EVO-X3 display — auto-refresh {refresh_sec}s — localhost:{port}</div>
  <img id="screen" alt="EVO-X3 display" src="/screen.png">
  <script>
    var img = document.getElementById("screen");
    function tick() {{ img.src = "/screen.png?t=" + Date.now(); }}
    setInterval(tick, {refresh_ms});
  </script>
</body>
</html>
"""


def _run(cmd: list[str]) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(cmd, capture_output=True, timeout=20)


def capture(dest: Path) -> str:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".tmp.png")
    if tmp.exists():
        tmp.unlink()

    attempts: list[tuple[str, list[str]]] = []
    if shutil.which("grim"):
        attempts.append(("grim", ["grim", str(tmp)]))
    if shutil.which("gnome-screenshot"):
        attempts.append(("gnome-screenshot", ["gnome-screenshot", f"--file={tmp}"]))
    if shutil.which("gdbus"):
        attempts.append(
            (
                "gdbus",
                [
                    "gdbus",
                    "call",
                    "--session",
                    "--dest",
                    "org.gnome.Shell.Screenshot",
                    "--object-path",
                    "/org/gnome/Shell/Screenshot",
                    "--method",
                    "org.gnome.Shell.Screenshot.Screenshot",
                    "false",
                    "false",
                    str(tmp),
                ],
            )
        )

    errors: list[str] = []
    if not attempts:
        raise RuntimeError("no capture tool (install grim or gnome-screenshot)")

    for name, cmd in attempts:
        proc = _run(cmd)
        if proc.returncode == 0 and tmp.is_file() and tmp.stat().st_size > 0:
            tmp.replace(dest)
            return name
        err = (proc.stderr or proc.stdout or b"").decode("utf-8", "replace").strip()
        errors.append(f"{name}: exit {proc.returncode} {err[:200]}")
        if tmp.exists():
            tmp.unlink()

    raise RuntimeError("; ".join(errors) if errors else "capture failed")


def capture_locked() -> None:
    global _last_method, _last_error, _last_ok_ts
    with _lock:
        try:
            _last_method = capture(PNG_PATH)
            _last_error = ""
            _last_ok_ts = time.time()
        except Exception as exc:  # noqa: BLE001 — operator-facing capture fallback
            _last_error = str(exc)
            if not PNG_PATH.is_file():
                raise


class Handler(BaseHTTPRequestHandler):
    server_version = "EVOX3ScreenPreview/1"

    def log_message(self, fmt: str, *args: object) -> None:
        return

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            html = INDEX_HTML.format(
                refresh_ms=REFRESH_MS,
                refresh_sec=max(1, REFRESH_MS // 1000),
                port=PORT,
            )
            self._send(200, html.encode("utf-8"), "text/html; charset=utf-8")
            return
        if path == "/health":
            payload = {
                "ok": (not _last_error) and PNG_PATH.is_file(),
                "method": _last_method,
                "error": _last_error,
                "last_ok_ts": int(_last_ok_ts) if _last_ok_ts else 0,
                "DISPLAY": os.environ.get("DISPLAY", ""),
                "WAYLAND_DISPLAY": os.environ.get("WAYLAND_DISPLAY", ""),
            }
            self._send(200, json.dumps(payload).encode("utf-8"), "application/json")
            return
        if path == "/screen.png":
            try:
                capture_locked()
            except Exception as exc:  # noqa: BLE001
                msg = (
                    "<!DOCTYPE html><html><body><pre>Capture failed: "
                    f"{exc}\nDISPLAY={os.environ.get('DISPLAY', '')} "
                    f"WAYLAND_DISPLAY={os.environ.get('WAYLAND_DISPLAY', '')}\n"
                    "Need a logged-in GNOME session on EVO-X3. "
                    "Retry: ./scripts/evox3/10_relaunch_kiosk.sh</pre></body></html>"
                )
                self._send(503, msg.encode("utf-8"), "text/html; charset=utf-8")
                return
            data = PNG_PATH.read_bytes()
            self._send(200, data, "image/png")
            return
        self._send(404, b"not found\n", "text/plain; charset=utf-8")


def main() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        capture_locked()
        print(f"[+] initial capture via {_last_method}", flush=True)
    except Exception as exc:  # noqa: BLE001
        print(f"[!] initial capture failed: {exc}", flush=True)
        print("[!] HTTP will keep retrying on /screen.png", flush=True)

    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[+] screen preview http://{HOST}:{PORT}/", flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
