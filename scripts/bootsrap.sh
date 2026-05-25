#!/usr/bin/env bash
# bootstrap_ianstaller.sh
# Usage: curl <url> | bash -s -- <IP>
#    or: bash bootstrap_ianstaller.sh <IP>

set -euo pipefail

# ── Argument check ────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <IP>"
    exit 1
fi

IP="$1"

# ── Ensure rsync is available (live Arch ISO may not have it) ─────────────────
if ! command -v rsync &>/dev/null; then
    echo "[*] rsync not found — installing via pacman..."
    pacman -Sy --noconfirm rsync
fi

# ── Sync project from remote host ─────────────────────────────────────────────
echo "[*] Syncing Ianstaller from wiian@${IP}..."
rsync -avzP "wiian@${IP}:/home/wiian/Projects/Ianstaller" . \
    --exclude "repo-official/"

# ── Run installer repo setup ──────────────────────────────────────────────────
echo "[*] Running setup_installer_repos.sh with IP: ${IP}..."
bash Ianstaller/scripts/setup_installer_repos.sh "${IP}"

echo "[*] Bootstrap complete."