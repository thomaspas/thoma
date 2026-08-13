#!/usr/bin/env bash
# Shared helpers for EVO-X3 operator scripts (ASCII only).
# Jinhua kiosk units are retired (26); GBrain Level 5 is current (27/28).
set -euo pipefail
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

EVOX3_AI_APPS="${EVOX3_AI_APPS:-$HOME/ai_apps}"
EVOX3_JINHUA_DIR="${EVOX3_JINHUA_DIR:-$EVOX3_AI_APPS/IncubativeSecondBrain}"
EVOX3_JINHUA_REPO="${EVOX3_JINHUA_REPO:-https://github.com/JinhuaChenBiggest/IncubativeSecondBrain.git}"
EVOX3_BGE_DIR="${EVOX3_BGE_DIR:-$EVOX3_AI_APPS/bge-m3-server}"
EVOX3_LLM_BASE_URL="${EVOX3_LLM_BASE_URL:-http://127.0.0.1:11434/v1}"
EVOX3_EMBED_BASE_URL="${EVOX3_EMBED_BASE_URL:-http://127.0.0.1:8002/v1}"
# Placeholder aliases — llama-server expects the live GGUF id from /v1/models.
EVOX3_LLM_MODEL="${EVOX3_LLM_MODEL:-auto}"
EVOX3_EMBED_MODEL="${EVOX3_EMBED_MODEL:-BAAI/bge-m3}"
EVOX3_API_HOST="${EVOX3_API_HOST:-127.0.0.1}"
EVOX3_API_PORT="${EVOX3_API_PORT:-8000}"
EVOX3_WEB_PORT="${EVOX3_WEB_PORT:-5173}"
EVOX3_BGE_PORT="${EVOX3_BGE_PORT:-8002}"
EVOX3_PIP_INDEX="${EVOX3_PIP_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
EVOX3_PIP_INDEX_FALLBACK="${EVOX3_PIP_INDEX_FALLBACK:-https://mirrors.aliyun.com/pypi/simple}"
# Fixed local kiosk account (auto-seed + skip AuthScreen). Local-only.
EVOX3_LOCAL_EMAIL="${EVOX3_LOCAL_EMAIL:-ye@evox3.local}"
EVOX3_LOCAL_PASSWORD="${EVOX3_LOCAL_PASSWORD:-evox3-local-12}"
EVOX3_LOCAL_DISPLAY_NAME="${EVOX3_LOCAL_DISPLAY_NAME:-Ye}"
# Product brand on the kiosk UI (IncubativeSecondBrain patch).
EVOX3_BRAND_NAME="${EVOX3_BRAND_NAME:-ANGELICA}"
EVOX3_BRAND_TAGLINE="${EVOX3_BRAND_TAGLINE:-Local second brain}"
EVOX3_BRAND_MARK="${EVOX3_BRAND_MARK:-AN}"
EVOX3_BRAND_TITLE="${EVOX3_BRAND_TITLE:-${EVOX3_BRAND_NAME} · Local second brain}"
# GBrain Level 5 (ANGELICA). Workspace is NOT ~/thoma.
EVOX3_GBRAIN_HOME="${EVOX3_GBRAIN_HOME:-$HOME/gbrain-agent}"
EVOX3_GBRAIN_HTTP_PORT="${EVOX3_GBRAIN_HTTP_PORT:-3131}"
EVOX3_GBRAIN_HTTP_BIND="${EVOX3_GBRAIN_HTTP_BIND:-127.0.0.1}"
EVOX3_GBRAIN_UNIT="${EVOX3_GBRAIN_UNIT:-angelica-gbrain.service}"
EVOX3_JINHUA_ARCHIVE="${EVOX3_JINHUA_ARCHIVE:-$EVOX3_AI_APPS/IncubativeSecondBrain.archived}"
EVOX3_JINHUA_UNITS="${EVOX3_JINHUA_UNITS:-evox3-jinhua-docker.service evox3-bge-m3.service evox3-jinhua-api.service evox3-jinhua-web.service}"

log() { printf '[*] %s\n' "$*"; }
ok() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[x] %s\n' "$*" >&2; exit 1; }

is_placeholder_llm_model() {
  case "${1:-}" in
    ""|auto|qwen|qwen3|qwen3.6|qwen3.6-27b|qwen3-27b) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve LLM_MODEL: explicit env > existing .env > llama-server /v1/models > warn+auto.
# Optional arg: path to IncubativeSecondBrain .env
resolve_llm_model() {
  local env_path="${1:-$EVOX3_JINHUA_DIR/.env}"
  local existing="" id="" models_json=""

  if ! is_placeholder_llm_model "${EVOX3_LLM_MODEL:-}"; then
    printf '%s\n' "$EVOX3_LLM_MODEL"
    return 0
  fi

  if [ -f "$env_path" ]; then
    existing="$(
      python3 - <<PY
from pathlib import Path
p = Path("$env_path")
for line in p.read_text().splitlines():
    if line.startswith("LLM_MODEL="):
        print(line.split("=", 1)[1].strip().strip('"').strip("'"))
        break
PY
    )"
    if ! is_placeholder_llm_model "$existing"; then
      printf '%s\n' "$existing"
      return 0
    fi
  fi

  if command -v curl >/dev/null 2>&1; then
    models_json="$(curl -fsS --max-time 5 "${EVOX3_LLM_BASE_URL}/models" 2>/dev/null || true)"
    if [ -n "$models_json" ]; then
      id="$(
        printf '%s' "$models_json" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    models = data.get("data") or []
    print((models[0].get("id") if models else "") or "")
except Exception:
    print("")
'
      )"
      if [ -n "$id" ]; then
        # Must go to stderr — stdout is captured by callers assigning EVOX3_LLM_MODEL.
        printf '[+] Auto-detected LLM_MODEL from llama-server: %s\n' "$id" >&2
        printf '%s\n' "$id"
        return 0
      fi
    fi
  fi

  warn "Could not auto-detect LLM_MODEL from ${EVOX3_LLM_BASE_URL}/models — set EVOX3_LLM_MODEL explicitly"
  printf '%s\n' "${EVOX3_LLM_MODEL:-auto}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

ensure_dir() {
  mkdir -p "$1"
}

# Wait until TCP host:port accepts connections (uses bash /dev/tcp).
wait_for_tcp() {
  local host="$1"
  local port="$2"
  local timeout_sec="${3:-60}"
  local i
  for i in $(seq 1 "$timeout_sec"); do
    if (echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Write + enable user unit that brings docker compose infra up on login/boot (linger).
install_jinhua_docker_unit() {
  local unit_dir unit_path
  require_cmd docker
  require_cmd systemctl
  [ -d "$EVOX3_JINHUA_DIR" ] || die "Missing $EVOX3_JINHUA_DIR"
  unit_dir="$(user_systemd_dir)"
  unit_path="$unit_dir/evox3-jinhua-docker.service"
  cat >"$unit_path" <<EOF
[Unit]
Description=EVO-X3 Jinhua docker compose (Postgres + Neo4j + MinIO)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${EVOX3_JINHUA_DIR}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose stop
TimeoutStartSec=180

[Install]
WantedBy=default.target
EOF
  reload_user_systemd
  systemctl --user enable --now evox3-jinhua-docker.service
  ok "Enabled evox3-jinhua-docker.service (compose on boot/login)"
}

user_systemd_dir() {
  ensure_dir "$HOME/.config/systemd/user"
  printf '%s\n' "$HOME/.config/systemd/user"
}

ensure_bun_on_path() {
  if [ -d "$HOME/.bun/bin" ]; then
    case ":$PATH:" in
      *":$HOME/.bun/bin:"*) ;;
      *) export PATH="$HOME/.bun/bin:$PATH" ;;
    esac
  fi
}

# Stop + disable a user unit if the unit file exists. Missing unit is OK.
stop_disable_user_unit() {
  local unit="$1"
  local unit_path="$HOME/.config/systemd/user/${unit}"
  if [ ! -f "$unit_path" ] && ! systemctl --user list-unit-files --plain 2>/dev/null | grep -q "^${unit}"; then
    ok "Unit not installed: $unit"
    return 0
  fi
  systemctl --user stop "$unit" 2>/dev/null || true
  systemctl --user disable "$unit" 2>/dev/null || true
  ok "Stopped and disabled $unit"
}

# Refuse GBrain workspace inside the thoma operator repo.
assert_gbrain_home_not_thoma() {
  local home="${1:-$EVOX3_GBRAIN_HOME}"
  local base
  base="$(basename "$home")"
  if [ "$home" = "$HOME/thoma" ] || [ "$base" = "thoma" ]; then
    die "GBrain workspace cannot be ~/thoma (got $home). Use ~/gbrain-agent."
  fi
  if [ -f "$home/.git/config" ] && grep -q 'thomaspas/thoma' "$home/.git/config" 2>/dev/null; then
    die "Refusing GBrain init inside a thoma clone ($home)"
  fi
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

# Import DISPLAY/WAYLAND/DBUS from the logged-in GNOME session (SSH → local desktop).
import_graphical_env_from_desktop_session() {
  local pid entry key val uid sess display imported=0
  uid="$(id -u)"
  for pid in $(pgrep -u "$uid" -x gnome-shell 2>/dev/null) $(pgrep -u "$uid" gnome-session-b 2>/dev/null) $(pgrep -u "$uid" -x mutter 2>/dev/null); do
    [ -n "$pid" ] || continue
    [ -r "/proc/${pid}/environ" ] || continue
    while IFS= read -r -d '' entry; do
      key="${entry%%=*}"
      val="${entry#*=}"
      case "$key" in
        DISPLAY|WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS|XAUTHORITY|XDG_SESSION_TYPE|XDG_CURRENT_DESKTOP)
          export "$key=$val"
          imported=1
          ;;
      esac
    done < "/proc/${pid}/environ"
  done
  if command -v loginctl >/dev/null 2>&1; then
    sess="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$USER" '$3==u {print $1; exit}')"
    if [ -n "$sess" ]; then
      display="$(loginctl show-session "$sess" -p Display --value 2>/dev/null || true)"
      if [ -n "$display" ]; then
        export DISPLAY="$display"
        imported=1
      fi
    fi
  fi
  if [ "$imported" -eq 1 ] && [ -n "${THOMA_DEBUG_LOG:-}" ]; then
    python3 -c "import json,time,os; open(os.environ.get('THOMA_DEBUG_LOG','/tmp/thoma-debug-f7f922.ndjson'),'a').write(json.dumps({'sessionId':'f7f922','hypothesisId':'H6','location':'_lib.sh:import_graphical','message':'imported desktop env','data':{'DISPLAY':os.environ.get('DISPLAY'),'WAYLAND':os.environ.get('WAYLAND_DISPLAY'),'XDG_RUNTIME_DIR':os.environ.get('XDG_RUNTIME_DIR')},'timestamp':int(time.time()*1000)})+'\n')" 2>/dev/null || true
  fi
  return 0
}

# Prepare env so Flatpak/Chromium can open on the LOCAL desktop from SSH.
# Exports: XDG_RUNTIME_DIR, DBUS_SESSION_BUS_ADDRESS, WAYLAND_DISPLAY, DISPLAY, XAUTHORITY
setup_local_graphical_env() {
  local uid runtime wl auth candidate
  import_graphical_env_from_desktop_session
  uid="$(id -u)"
  runtime="${XDG_RUNTIME_DIR:-/run/user/${uid}}"
  export XDG_RUNTIME_DIR="$runtime"

  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "${runtime}/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${runtime}/bus"
  fi

  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    for wl in wayland-0 wayland-1; do
      if [ -S "${runtime}/${wl}" ]; then
        export WAYLAND_DISPLAY="$wl"
        break
      fi
    done
  fi

  export DISPLAY="${DISPLAY:-:0}"

  if [ -z "${XAUTHORITY:-}" ] || [ ! -f "${XAUTHORITY}" ]; then
    for candidate in \
      "${HOME}/.Xauthority" \
      "${runtime}/gdm/Xauthority" \
      "${runtime}/.mutter-Xwaylandauth."*
    do
      if [ -f "$candidate" ]; then
        export XAUTHORITY="$candidate"
        break
      fi
    done
  fi

  log "Graphical env: DISPLAY=${DISPLAY:-?} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-none} XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR} XAUTHORITY=${XAUTHORITY:-none}"

  if [ -z "${WAYLAND_DISPLAY:-}" ] && { [ -z "${XAUTHORITY:-}" ] || [ ! -f "${XAUTHORITY}" ]; }; then
    warn "No Wayland socket and no XAUTHORITY — GUI launch from this SSH session will likely fail"
    warn "Retry: ./scripts/evox3/10_relaunch_kiosk.sh then ./scripts/evox3/21_remote_verify.sh"
  fi
}

# Flatpak Chromium: URL as final arg (--app= alone is unreliable).
# Dedicated --user-data-dir avoids "Opening in existing browser session" (URL absent from cmdline).
# Prefer Wayland ozone when WAYLAND_DISPLAY is set (EVO-X3 desktop is Wayland).
kiosk_launch_cmd() {
  local url="$1"
  local c ozone=""
  local profile="/tmp/evox3-jinhua-kiosk-chromium"
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    ozone='--ozone-platform=wayland'
  fi
  if command -v flatpak >/dev/null 2>&1; then
    if flatpak info io.github.ungoogled_software.ungoogled_chromium >/dev/null 2>&1; then
      printf 'flatpak run io.github.ungoogled_software.ungoogled_chromium --user-data-dir=%q --new-window --kiosk --no-first-run --disable-session-crashed-bubble %s %q' "$profile" "$ozone" "$url"
      return 0
    fi
    if flatpak info org.chromium.Chromium >/dev/null 2>&1; then
      printf 'flatpak run org.chromium.Chromium --user-data-dir=%q --new-window --kiosk --no-first-run --disable-session-crashed-bubble %s %q' "$profile" "$ozone" "$url"
      return 0
    fi
  fi
  c="$(pick_browser || true)"
  if [ -z "$c" ]; then
    return 1
  fi
  if [ "$c" = "firefox" ]; then
    printf '%q -kiosk %q' "$c" "$url"
  else
    printf '%q --user-data-dir=%q --new-window --kiosk --app=%q --no-first-run --disable-session-crashed-bubble %s' "$c" "$profile" "$url" "$ozone"
  fi
}

# True if any browser/kiosk-related process cmdline references the Vite web port.
# Flatpak/bwrap often hide the URL from pgrep -af; scan /proc/*/cmdline.
kiosk_references_web_port() {
  local port="${EVOX3_WEB_PORT:-5173}"
  local pid cmd
  for pid in /proc/[0-9]*; do
    [ -r "${pid}/cmdline" ] || continue
    cmd="$(tr '\0' ' ' < "${pid}/cmdline" 2>/dev/null || true)"
    case "$cmd" in
      *ungoogled_chromium*|*org.chromium*|*chromium*|*firefox*|*evox3-jinhua-kiosk*|*flatpak*)
        if printf '%s' "$cmd" | grep -qE ":${port}(/|\"|'|[[:space:]]|$)|127\.0\.0\.1:${port}"; then
          return 0
        fi
        ;;
    esac
  done
  return 1
}

wait_for_kiosk_web_port() {
  local secs="${1:-45}"
  local i
  for i in $(seq 1 "$secs"); do
    if kiosk_references_web_port; then
      return 0
    fi
    sleep 1
  done
  return 1
}

kiosk_proc_snapshot() {
  pgrep -af 'ungoogled_chromium|org.chromium|chromium|firefox|evox3-jinhua-kiosk|flatpak' 2>/dev/null | head -n 40 || true
}

