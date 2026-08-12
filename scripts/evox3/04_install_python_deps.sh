#!/usr/bin/env bash
# Create venv and install Jinhua Python deps (mirrors for reliability).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3

[ -d "$EVOX3_JINHUA_DIR" ] || die "Missing $EVOX3_JINHUA_DIR — run 02 first"
[ -f "$EVOX3_JINHUA_DIR/.env" ] || warn ".env missing — run 03_write_local_env.sh"

cd "$EVOX3_JINHUA_DIR"

if [ ! -x .venv/bin/python ]; then
  log "Creating venv at $EVOX3_JINHUA_DIR/.venv"
  python3 -m venv .venv
fi

log "Upgrading pip/setuptools/wheel"
pip_install .venv/bin/pip --upgrade pip setuptools wheel

log "Installing package extras: .[dev,llm]"
pip_install .venv/bin/pip -e ".[dev,llm]"

.venv/bin/python -c 'import fastapi, uvicorn, alembic; print("IMPORT_OK")'
ok "04_install_python_deps.sh complete"
