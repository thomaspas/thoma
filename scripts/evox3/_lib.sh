#!/usr/bin/env bash
# Shared helpers for EVO-X3 LOCAL FULL Jinhua scripts (ASCII only).
set -euo pipefail
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

EVOX3_AI_APPS="${EVOX3_AI_APPS:-$HOME/ai_apps}"
EVOX3_JINHUA_DIR="${EVOX3_JINHUA_DIR:-$EVOX3_AI_APPS/IncubativeSecondBrain}"
EVOX3_JINHUA_REPO="${EVOX3_JINHUA_REPO:-https://github.com/JinhuaChenBiggest/IncubativeSecondBrain.git}"
EVOX3_BGE_DIR="${EVOX3_BGE_DIR:-$EVOX3_AI_APPS/bge-m3-server}"
EVOX3_LLM_BASE_URL="${EVOX3_LLM_BASE_URL:-http://127.0.0.1:11434/v1}"
EVOX3_EMBED_BASE_URL="${EVOX3_EMBED_BASE_URL:-http://127.0.0.1:8002/v1}"
EVOX3_LLM_MODEL="${EVOX3_LLM_MODEL:-qwen}"
EVOX3_EMBED_MODEL="${EVOX3_EMBED_MODEL:-BAAI/bge-m3}"
EVOX3_API_HOST="${EVOX3_API_HOST:-127.0.0.1}"
EVOX3_API_PORT="${EVOX3_API_PORT:-8000}"
EVOX3_WEB_PORT="${EVOX3_WEB_PORT:-5173}"
EVOX3_BGE_PORT="${EVOX3_BGE_PORT:-8002}"
EVOX3_PIP_INDEX="${EVOX3_PIP_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
EVOX3_PIP_INDEX_FALLBACK="${EVOX3_PIP_INDEX_FALLBACK:-https://mirrors.aliyun.com/pypi/simple}"

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

ensure_dir() {
  mkdir -p "$1"
}

user_systemd_dir() {
  ensure_dir "$HOME/.config/systemd/user"
  printf '%s\n' "$HOME/.config/systemd/user"
}

reload_user_systemd() {
  systemctl --user daemon-reload
}

enable_linger_hint() {
  if ! loginctl show-user "$USER" -p Linger 2>/dev/null | grep -q 'Linger=yes'; then
    warn "User linger is off. For services after logout, run: sudo loginctl enable-linger $USER"
  fi
}

pip_install() {
  local venv_pip="$1"
  shift
  if ! "$venv_pip" install -q --default-timeout=60 -i "$EVOX3_PIP_INDEX" "$@"; then
    warn "Primary pip index failed; trying fallback mirror"
    "$venv_pip" install -q --default-timeout=60 -i "$EVOX3_PIP_INDEX_FALLBACK" "$@"
  fi
}

pick_browser() {
  local c
  for c in chromium-browser chromium google-chrome google-chrome-stable firefox; do
    if command -v "$c" >/dev/null 2>&1; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}
