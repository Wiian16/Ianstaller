#!/usr/bin/env bash
set -euo pipefail

HOST_IP="$1"   # pass in host IP from your VM automation
PORT="${2:-8080}"

if [[ -z "$HOST_IP" ]]; then
    echo "Usage: setup_installer_repos.sh <host-ip> [port]"
    exit 1
fi

PACMAN_CONF="/etc/pacman.conf"
TMP_NEW="/tmp/pacman.conf.new.$$"
TMP_BLOCK="/tmp/localrepo_block.$$"

# Build the repo block into a temp file (newline-preserving)
cat > "$TMP_BLOCK" <<EOF
[localrepo]
Server = http://$HOST_IP:$PORT/
SigLevel = Never

EOF

echo "[+] Removing any existing [localrepo] block from $PACMAN_CONF..."
sudo sed -i '/^\[localrepo\]/,/^$/d' "$PACMAN_CONF"

# Determine insertion point: after [options] section if present
if sudo grep -q '^\[options\]' "$PACMAN_CONF"; then
    echo "[+] Inserting [localrepo] block after [options] section..."

    # AWK logic:
    # - Print normally until inside [options]
    # - When the next section header appears, print the block FILE, then continue
    sudo awk -v blockfile="$TMP_BLOCK" '
    BEGIN { in_options = 0 }
    /^\[options\]/ {
        print
        in_options = 1
        next
    }
    {
        if (in_options) {
            if (/^\[/) {
                # Insert block before the next section
                while ((getline line < blockfile) > 0) print line
                close(blockfile)
                in_options = 0
            }
        }
        print
    }
    END {
        # If file ended while still in options, append block at end
        if (in_options) {
            while ((getline line < blockfile) > 0) print line
            close(blockfile)
        }
    }
    ' "$PACMAN_CONF" > "$TMP_NEW"

else
    echo "[+] No [options] section found; prepending [localrepo] block..."
    sudo sh -c "cat '$TMP_BLOCK' '$PACMAN_CONF' > '$TMP_NEW'"
fi

# Replace pacman.conf
sudo mv "$TMP_NEW" "$PACMAN_CONF"
sudo chmod 644 "$PACMAN_CONF"
rm -f "$TMP_BLOCK"

echo "[+] Refreshing pacman databases..."
sudo pacman -Syy

echo "[+] Local repo setup complete."

