#!/usr/bin/env bash
# helpers.sh -- Core utility functions for ianstaller

# ==============================
# Logging and Formatting
# ==============================

# Color codes
CLR_RESET="\033[0m"
CLR_BOLD="\033[1m"
CLR_RED="\033[1;31m"
CLR_GREEN="\033[1;32m"
CLR_YELLOW="\033[1;33m"
CLR_BLUE="\033[1;34m"
CLR_GRAY="\033[0;37m"

# Timestap generator
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Core log function
log() {
    local level="$1"
    shift
    local color="$1"
    shift
    local message="$*"
    echo -e "${color}[$(timestamp)] [$level]${CLR_RESET} $message"
}

# Log levels
info() { log "INFO" "$CLR_GREEN" "$*"; }
warn() { log "WARN" "$CLR_YELLOW" "$*"; }
error() { log "ERROR" "$CLR_RED" "$*"; }
debug() { [[ "$DEBUG" == true ]] && log "DEBUG" "$CLR_BLUE" "$*"; }

# ==============================
# Command Wrappers
# ==============================

# Dry-run global flag (set in install.sh)
: "${DRY_RUN:=false}"

run() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] $*"
    else
        info "Running: $*"
        "$@" || error "Command failed: $*"
    fi
}

# Run as root
run_sudo() {
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] sudo $*"
    else
        info "sudo $*"
        sudo "$@" || error "Command failed (sudo): $*"
    fi
}

# ==============================
# Prompt and Input Handling
# ==============================

# Simple yes/no confirmation
confirm() {
    local prompt="${1:-Are you sure?}"
    read -rp "$prompt [y/N]: " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Pause until user presses Enter
pause() {
    read -rp "Press Enter to continue..."
}

# Prompt for input (no default)
prompt() {
    local var_name="$1"
    local prompt_text="$2"

    read -rp "$prompt_text: " input
    eval "$var_name=\"\$input\""
}

# Prompt for input with a default value
prompt_default() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="$3"

    read -rp "$prompt_text [${default_value}]: " input
    # If the user pressed Enter, use the default
    eval "$var_name=\"\${input:-$default_value}\""
}

validate_username() {
    local username="$1"

    # Reject "root" explicitly
    if [[ "$username" == "root" ]]; then
        return 1
    fi

    # POSIX-compliant username pattern
    # Must start with lowercase letter or underscore
    # Followed by up to 31 lowercase letters, digits, underscores, or hyphens
    if [[ ! "$username" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
        return 1
    fi

    return 0
}

validate_hostname() {
    local hostname="$1"

    # Empty hostname is invalid
    [[ -z "$hostname" ]] && return 1

    # Must not be "localhost"
    if [[ "$hostname" == "localhost" ]]; then
        return 1
    fi

    # RFC 1123-compliant pattern:
    #   - letters, digits, hyphens allowed
    #   - cannot start or end with a hyphen
    #   - labels separated by dots
    if [[ ! "$hostname" =~ ^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9-]{0,61}[A-Za-z0-9])$ ]]; then
        return 1
    fi

    # Total length check
    if ((${#hostname} > 253)); then
        return 1
    fi

    return 0
}

validate_timezone() {
    local timezone="$1"

    if [ -f "/usr/share/zoneinfo/$1" ]; then
        return 1
    fi

    return 0
}

validate_locale() {
    local locale="$1"

    if grep -q "$locale" "/etc/locale.gen"; then
        return 0
    fi

    return 1
}

validate_install_type() {
    local type="$1"

    case "$type" in
    drive | partition)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

validate_partition() {
    local location="$1"

    if lsblk -o NAME --filter 'TYPE == "part"' | grep -qx "$location"; then
        return 0
    fi

    return 1
}

validate_drive() {
    local location="$1"

    if lsblk -o NAME --filter 'TYPE == "disk"' | grep -qx "$location"; then
        return 0
    fi

    return 1
}

# ==============================
# File and Path Utilities
# ==============================

# Ensure directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        info "Creating directory: $dir"
        run mkdir -p "$dir"
    fi
}

# Backup a file safely
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.$(date +%Y%m%d%H%M%S).bak"
        info "Backing up $file -> $backup"
        run cp "$file" "$backup"
    fi
}

# Append a line if missing
append_if_missing() {
    local line="$1"
    local file="$2"
    grep -Fxq "$line" "$file" 2>/dev/null || echo "$line" | run tee -a "$file" >/dev/null
}

# ==============================
# System Checks and Validation
# ==============================

# Ensure script is run as root (or check sudo available)
require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "This script must be run as root!"
    fi
}

require_sudo() {
    if ! command -v sudo &>/dev/null; then
        error "sudo is required but not installed."
    fi
}

require_cmd() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Missing dependency: $cmd"
        fi
    done
}

# ==============================
# Error Handling, Exiting, and Traps
# ==============================

# Trap handler
cleanup() {
    local status="${1:-success}"

    info "Starting cleanup process (mode: $status)..."
    sync
    sleep 2

    # Unmount order (reverse)
    if mountpoint -q /mnt/boot/efi; then
        info "Unmounting EFI..."
        run_sudo umount /mnt/boot/efi || warn "Failed to unmount EFI"
    fi

    if mountpoint -q /mnt/lib/modules; then
        info "Unmounting /lib/modules..."
        run_sudo umount /mnt/lib/modules || warn "Failed to unmount modules"
    fi

    if grep -q "/mnt" /proc/swaps; then
        info "Disabling swap..."
        run_sudo swapoff /mnt/swapfile || warn "Failed to disable swap"
    fi

    info "Killing processes using /mnt..."
    run_sudo fuser -km /mnt || true
    sleep 1

    if mountpoint -q /mnt; then
        info "Unmounting root mount..."
        run_sudo umount -R /mnt || warn "Failed to unmount /mnt"
    fi

    # Optional: handle temporary bind mounts, /mnt/chroot, etc.
    [[ -d /mnt ]] && info "Syncing final state..." && run_sudo sync

    case "$status" in
    success)
        info "Cleanup complete. Installation finished successfully."
        ;;
    error)
        warn "Cleanup complete after error. Manual verification recommended."
        ;;
    esac
}

# Graceful exit with message
fail() {
    error "$*"
    exit 1
}

# Retry logic for unstable commands
retry() {
    local attempts="$1"
    shift
    local delay="${2:-3}"
    shift
    local cmd=("$@")
    local count=0

    until "${cmd[@]}"; do
        ((count++))
        if ((count >= attempts)); then
            error "Command failed after $count attempts: ${cmd[*]}"
            return 1
        fi
        warn "Retrying (${count}/${attempts})..."
        sleep "$delay"
    done
}
