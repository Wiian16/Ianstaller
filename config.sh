#!/usr/bin/env bash
# ============================================
# Ianstaller v2 - Configuration Definition
# ============================================
# This file defines all configuration variables and
# setup functions. It is sourced by install.sh.
# ============================================

# ───────────────────────────────
# 1. USER CONFIGURATION VARIABLES
# ───────────────────────────────
USERNAME=""
PASSWORD=""
HOSTNAME=""
TIMEZONE=""
LOCALE=""
INSTALL_LOCATION=""
INSTALL_TYPE="" # Can be 'partition' or 'drive'
FILESYSTEM="btrfs"

# ───────────────────────────────
# 2. MODULE TOGGLES
# ───────────────────────────────
ENABLE_DESKTOP=true
ENABLE_DOTFILES=true
ENABLE_DEV=true
ENABLE_GAMING=true
ENABLE_LAPTOP=true

# ───────────────────────────────
# 3. PACKAGE LOADING
# ───────────────────────────────
read_package_list() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sed -e 's/#.*$//' -e '/^$/d' $file
    else
        error "Package file not found: $file"
        return 1
    fi
}

PACKAGES_CORE=($(read_package_list "packages/core.txt"))
PACKAGES_DESKTOP=($(read_package_list "packages/desktop.txt"))
PACKAGES_DEV=($(read_package_list "packages/dev.txt"))
PACKAGES_GAMING=($(read_package_list "packages/gaming.txt"))
PACKAGES_LAPTOP=($(read_package_list "packages/laptop.txt"))

# ───────────────────────────────
# 4. DOTFILES CONFIGURATION
# ───────────────────────────────
DOTFILES_REPO="https://github.com/Wiian16/DotFiles.git"
DOTFILES_TOOL="chezmoi"

# ───────────────────────────────
# 5. GLOBAL VARIABLES
# ───────────────────────────────
DRY_RUN=false
NO_CONFIRM=flase
LOG_FILE="ianstaller.log"

# ───────────────────────────────
# 6. SETUP CONFIGS
# ───────────────────────────────

setup_config() {
    while true; do
        prompt "USERNAME" "Enter your username"
        if validate_username "$USERNAME"; then
            break
        fi

        warn "Bad username, please try again"
    done

    while true; do
        prompt_silent "PASSWORD" "Enter your password (will also be root password)"

        if [[ ! -n "$PASSWORD" ]]; then
            warn "Password must not be empty, please try again"
            continue
        fi

        local first_password="$PASSWORD"

        prompt_silent "PASSWORD" "Confirm your password"

        if [ "$first_password" != "$PASSWORD" ]; then
            warn "Passwords must match, please try again"
            continue
        fi

        break
    done

    while true; do
        prompt_default "HOSTNAME" "Enter a hostname" "archlinux"
        if validate_hostname "$HOSTNAME"; then
            break
        fi

        warn "Bad username, please try again"
    done

    while true; do
        prompt_default "TIMEZONE" "Enter a timezone (e.g. America/New_York)" "UTC"
        if validate_timezone "TIMEZONE"; then
            break
        fi

        warn "Bad timezone, please try again"
    done

    while true; do
        prompt_default "LOCALE" "Enter a locale" "C.UTF-8"
        if validate_locale "$LOCALE"; then
            break
        fi

        warn "Bad locale, please try again"
    done

    while true; do
        prompt "INSTALL_TYPE" "Enter the install type (drive or partition)"
        INSTALL_TYPE="${INSTALL_TYPE,,}"
        if validate_install_type "$INSTALL_TYPE"; then
            break
        fi

        warn "Bad install type, please try again"
    done

    prompt_install_location
}

prompt_install_location() {
    local install_type="$INSTALL_TYPE"

    case "$install_type" in
    drive)
        prompt_install_drive
        ;;
    partition)
        if [ $(lsblk -o TYPE | grep "part" | wc -l) -le 0 ]; then
            error "No parittions detected, select 'drive' install type or create a partition and try again"
            false # Start error cleanup process then exit
        fi
        prompt_install_partition
        ;;
    *)
        fail "Internal error: Invalid install type after prompt"
        ;;
    esac
}

prompt_install_partition() {
    # List available partitions
    list_partitions

    while true; do
        prompt "INSTALL_LOCATION" "Enter a partition to install on (e.g. nvme0n1p2, sda1)"
        if validate_partition "$INSTALL_LOCATION"; then
            break
        fi

        warn "Invalid partition, please try again"
    done
}

list_partitions() {
    echo "Detected partitions:"

    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,PARTLABEL,MODEL,TYPE

    echo "Only entries with type 'part' will be accepted"

}

prompt_install_drive() {
    # List available drives
    list_disks

    while true; do
        prompt "INSTALL_LOCATION" "Enter a drive to install on (e.g. nvme0n1, sda)"
        if validate_drive "$INSTALL_LOCATION"; then
            break
        fi

        warn "Invalid drive, please try again"
    done
}

list_disks() {
    echo "Detected disks: "

    lsblk -o NAME,SIZE,LABEL,MODEL,TYPE --filter 'TYPE == "disk"'
}

# ───────────────────────────────
# 7. VALIDATION
# ───────────────────────────────
validate_config() {
    local missing=()

    for var in USERNAME PASSWORD HOSTNAME TIMEZONE LOCALE INSTALL_LOCATION INSTALL_TYPE; do
        [[ -z "${!var}" ]] && missing+=("$var")
    done

    if ((${#missing[@]})); then
        error "Missing required configuration values:"
        printf '  - %s\n' "${missing[@]}"
        exit 1
    fi
}
