#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Resolve project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PKG_DIR="$PROJECT_ROOT/packages"
REPO_DIR="$PROJECT_ROOT/repo-official"
CACHE_DIR="/var/cache/ianstaller/cache-official"
REPO_NAME="localrepo"

echo "Project root: $PROJECT_ROOT"
echo "Looking for package files in: $PKG_DIR"

# Find only non-AUR package lists
mapfile -t pkg_files < <(find "$PKG_DIR" -maxdepth 1 -type f -name "*.txt" ! -name "*-aur.txt" | sort)

if [[ ${#pkg_files[@]} -eq 0 ]]; then
    echo "ERROR: No official package list files found."
    exit 1
fi

echo "Found package list files:"
printf '  - %s\n' "${pkg_files[@]}"

# Parse official package names
packages=()
for f in "${pkg_files[@]}"; do
    while IFS= read -r line; do
        line="${line%%#*}"  # remove comments
        line="$(echo "$line" | xargs)"  # trim whitespace
        [[ -n "$line" ]] && packages+=("$line")
    done < "$f"
done

# Deduplicate
declare -A seen=()
uniq_pkgs=()
for p in "${packages[@]}"; do
    if [[ -z "${seen[$p]:-}" ]]; then
        uniq_pkgs+=("$p")
        seen[$p]=1
    fi
done

if [[ ${#uniq_pkgs[@]} -eq 0 ]]; then
    echo "ERROR: No official packages parsed."
    exit 1
fi

echo "Total distinct official packages: ${#uniq_pkgs[@]}"
echo "Sample: ${uniq_pkgs[@]:0:10}"

# Create directories
sudo mkdir -p "$REPO_DIR" "$CACHE_DIR"
sudo chown root:root "$CACHE_DIR"
sudo chmod 755 "$CACHE_DIR"

echo "[+] Downloading packages into cache (pacman -Sw)..."
sudo pacman -Sw --cachedir "$CACHE_DIR" --noconfirm "${uniq_pkgs[@]}"

# Collect downloaded packages
shopt -s nullglob
pkg_files_on_disk=( "$CACHE_DIR"/*.pkg.tar.* )

if [[ ${#pkg_files_on_disk[@]} -eq 0 ]]; then
    echo "ERROR: No downloaded packages in $CACHE_DIR."
    exit 1
fi

# Copy into repo
echo "[+] Copying packages into $REPO_DIR (excluding .sig files)"

# Copy only real packages
find "$CACHE_DIR" -maxdepth 1 -type f \
    \( -name "*.pkg.tar.zst" -o -name "*.pkg.tar.xz" -o -name "*.pkg.tar.gz" \) \
    -exec cp -v {} "$REPO_DIR" \; || true

echo "[+] Building repository database"
cd "$REPO_DIR"

# Remove old DB
rm -f "$REPO_NAME".db* || true

# Add only real package archives
repo-add "$REPO_NAME.db.tar.gz" ./*.pkg.tar.zst ./*.pkg.tar.xz ./*.pkg.tar.gz || true

echo "[+] Official repo built: $REPO_DIR"
