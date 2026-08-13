#!/usr/bin/env bash
# Enable GNOME Remote Desktop (RDP) on EVO-X3 from SSH / Cursor Remote SSH.
# Does NOT install TightVNC. Does NOT apt-install silently.
# Credentials live in ~/.config/evox3/grd-rdp.env (chmod 600) — never commit.
# Usage (on EVO-X3):
#   ./scripts/evox3/26_gnome_remote_desktop.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_lib.sh"

require_cmd python3

CRED_DIR="${EVOX3_GRD_CRED_DIR:-$HOME/.config/evox3}"
CRED_FILE="${EVOX3_GRD_CRED_FILE:-$CRED_DIR/grd-rdp.env}"
TLS_DIR="${EVOX3_GRD_TLS_DIR:-$HOME/.local/share/gnome-remote-desktop}"
RDP_PORT="${EVOX3_RDP_PORT:-3389}"
LAN_HINT="${EVOX3_SSH:-thomas-pashoulas@192.168.1.8}"
LAN_HOST="${LAN_HINT#*@}"

setup_local_graphical_env

if ! command -v grdctl >/dev/null 2>&1; then
  die "grdctl not found. On EVO-X3 install: sudo apt install gnome-remote-desktop (then re-run). Do not use TightVNC."
fi

ensure_dir "$CRED_DIR"
chmod 700 "$CRED_DIR" 2>/dev/null || true
ensure_dir "$TLS_DIR"

grd_help="$(grdctl --help 2>/dev/null || true)"
rdp_help="$(grdctl rdp --help 2>/dev/null || true)"

ensure_tls() {
  printf '%s\n%s\n' "$grd_help" "$rdp_help" | grep -q 'set-tls-cert' || return 0
  local crt="$TLS_DIR/rdp.crt" key="$TLS_DIR/rdp.key"
  if [ ! -s "$crt" ] || [ ! -s "$key" ]; then
    require_cmd openssl
    log "Generating self-signed RDP TLS cert in $TLS_DIR"
    openssl req -new -newkey rsa:4096 -days 730 -nodes -x509 \
      -subj "/CN=evox3-angelica-rdp" \
      -out "$crt" -keyout "$key" >/dev/null 2>&1 \
      || die "openssl failed to write $crt / $key"
    chmod 600 "$key"
    chmod 644 "$crt"
  fi
  grdctl rdp set-tls-cert "$crt" || die "grdctl rdp set-tls-cert failed"
  grdctl rdp set-tls-key "$key" || die "grdctl rdp set-tls-key failed"
  ok "RDP TLS cert set ($crt)"
}

load_or_create_creds() {
  local user pass created=0
  if [ -f "$CRED_FILE" ]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck source=/dev/null
    source "$CRED_FILE"
    set +a
  fi
  user="${EVOX3_RDP_USER:-$USER}"
  pass="${EVOX3_RDP_PASSWORD:-}"
  if [ -z "$pass" ]; then
    pass="$(python3 -c 'import secrets,string; a=string.ascii_letters+string.digits; print("".join(secrets.choice(a) for _ in range(20)))')"
    created=1
  fi
  umask 077
  cat >"$CRED_FILE" <<EOF
# Local-only GNOME RDP credentials for EVO-X3. chmod 600. Do not commit.
EVOX3_RDP_USER=${user}
EVOX3_RDP_PASSWORD=${pass}
EOF
  chmod 600 "$CRED_FILE"
  EVOX3_RDP_USER="$user"
  EVOX3_RDP_PASSWORD="$pass"
  if [ "$created" -eq 1 ]; then
    ok "Wrote new RDP credentials: $CRED_FILE"
  else
    ok "Using RDP credentials: $CRED_FILE"
  fi
}

enable_user_unit() {
  if [ -f "$HOME/.config/systemd/user/gnome-remote-desktop.service" ] \
    || systemctl --user list-unit-files gnome-remote-desktop.service >/dev/null 2>&1; then
    systemctl --user enable --now gnome-remote-desktop.service 2>/dev/null || true
  fi
}

printf '\n=== EVO-X3 GNOME Remote Desktop (RDP) ===\n'
log "grdctl=$(command -v grdctl)"

if ! pgrep -u "$(id -u)" -x gnome-shell >/dev/null 2>&1; then
  warn "gnome-shell not running for this user — RDP needs a logged-in GNOME session (same as kiosk)."
fi

load_or_create_creds
ensure_tls

if ! grdctl rdp set-credentials "$EVOX3_RDP_USER" "$EVOX3_RDP_PASSWORD"; then
  die "grdctl rdp set-credentials failed — is a GNOME session logged in?"
fi
ok "RDP credentials set (user=$EVOX3_RDP_USER)"

grdctl rdp enable || die "grdctl rdp enable failed"
ok "RDP enabled"

if printf '%s\n' "$rdp_help" | grep -q 'disable-view-only'; then
  grdctl rdp disable-view-only 2>/dev/null || true
fi

enable_user_unit

printf '\n--- grdctl status ---\n'
grdctl status 2>/dev/null || grdctl rdp status 2>/dev/null || true
printf '\n'

ok "Connect from Gaming-7 (Remmina / GNOME Connections):"
printf '  Protocol: RDP\n'
printf '  Host:     %s\n' "$LAN_HOST"
printf '  Port:     %s\n' "$RDP_PORT"
printf '  User:     %s\n' "$EVOX3_RDP_USER"
printf '  Password: see %s (chmod 600, not in git)\n' "$CRED_FILE"
printf '  URI:      rdp://%s@%s:%s\n' "$EVOX3_RDP_USER" "$LAN_HOST" "$RDP_PORT"
printf '\nThis is the live GNOME/kiosk monitor. Cursor Remote SSH stays for terminal + Agent.\n'
printf 'If connect fails: allow TCP %s on EVO (ufw) or confirm grdctl status shows RDP enabled.\n' "$RDP_PORT"
printf 'Do not bind Vite to 0.0.0.0 — UI preview is SSH port-forward :%s.\n' "$EVOX3_WEB_PORT"
ok "26_gnome_remote_desktop.sh complete"
