#!/usr/bin/env bash
# Copy remote-verify + kiosk SSH fixes from Gaming-7 clone to EVO-X3 (run ON Gaming-7).
set -euo pipefail
EVO="${EVOX3_SSH:-thomas-pashoulas@192.168.1.8}"
SRC="${1:-$HOME/thoma}"
FILES=(
  scripts/evox3/_lib.sh
  scripts/evox3/08_autostart_desktop.sh
  scripts/evox3/10_relaunch_kiosk.sh
  scripts/evox3/21_remote_verify.sh
  scripts/evox3/22_operator_context_check.sh
  scripts/evox3/23_sync_verify_fix_to_evox3.sh
)
for f in "${FILES[@]}"; do
  echo "[*] scp $f -> $EVO:~/thoma/$f"
  scp "$SRC/$f" "$EVO:~/thoma/$f"
done
echo "[+] Done. On EVO-X3 run:"
echo "    cd ~/thoma && chmod +x scripts/evox3/*.sh && ./scripts/evox3/21_remote_verify.sh"
