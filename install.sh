#!/usr/bin/env bash
# ========================================
# Ianstaller v2 -- Main Installer Entrypoint
# ========================================

set -Eeuo pipefail

# Source helper utilites and configuration
source ./config.sh
source ./modules/helpers.sh

# Source all modules
source ./modules/00-partition.sh
source ./modules/01-btrfs.sh
source ./modules/02-base.sh
source ./modules/03-chroot.sh
source ./modules/04-system.sh
source ./modules/05-desktop.sh
source ./modules/06-dotfiles.sh
source ./modules/07-devtools.sh
source ./modules/08-gaming.sh
source ./modules/09-laptop.sh
source ./modules/10-postinstall.sh

# ───────────────────────────────
# USAGE AND HELP
# ───────────────────────────────

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dry-run              Print commands instead of executing them
  --skip <module>        Skip one or more modules (e.g. --skip desktop --skip gaming)
  --no-confirm           Skip all interactive confirmations
  --help                 Show this help message

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --skip desktop --skip gaming
EOF
}

# ───────────────────────────────
# USAGE AND HELP
# ───────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --no-confirm)
            NO_CONFIRM=true
            ;;
        --skip)
            if [[ -z "$2" || "$2" =~ ^-- ]]; then
                error "--skip requires a module name"
                exit 1
            fi
            skip_module "$2"
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
        esac
        shift
    done
}

skip_module() {
    case "${1,,}" in
    "desktop")
        ENABLE_DESKTOP=false
        ;;
    "dev")
        ENABLE_DEV=false
        ;;
    "dotiles")
        ENABLE_DOTFILES=false
        ;;
    "gaming")
        ENABLE_GAMING=false
        ;;
    "laptop")
        ENABLE_LAPTOP=false
        ;;
    *)
        error "Unknown module, must be one of desktop, dotiles, dev, gaming, laptop"
        exit 1
        ;;
    esac
}

# ───────────────────────────────
# 4. MAIN EXECUTION FLOW
# ───────────────────────────────

main() {
    parse_args "$@"

    trap 'cleanup error' ERR
    trap 'cleanup success' EXIT

    info "Starting Ianstaller"
    info "Dry run: $DRY_RUN"

    setup_config
    validate_config

    # Run all modules skipping where specified

    # Partition
    info "Running module 00: Partition"
    module_00
    # Mount
    info "Running Module 01: Mount"
    module_01
    # Base
    info "Running Module 02: Base"
    module_02
    # Chroot
    info "Running Module 03: Chroot"
    module_03
    # SYstem
    info "Running Module 04: System"
    module_04
    # Desktop
    if $ENABLE_DESKTOP; then
        info "Running Module 05: Desktop"
        module_05
    else
        warn "Skipping Module 05: Desktop"
    fi
    # Dotfiles
    if $ENABLE_DOTFILES; then
        info "Running Module 05: Dotfiles"
        module_06
    else
        warn "Skipping Module 06: Dotfiles"
    fi
    # Devtools
    if $ENABLE_DEV; then
        info "Running Module 07: Devtools"
        module_07
    else
        warn "Skipping Module 07: Devtools"
    fi
    # Gaming
    if $ENABLE_GAMING; then
        info "Running Module 08: Gaming"
        module_08
    else
        warn "Skipping Module 08: Gaming"
    fi
    # Laptop
    if $ENABLE_LAPTOP; then
        info "Running Module 09: Laptop"
        module_09
    else
        warn "Skipping Module 09: Laptop"
    fi
    # Postinstall
    info "Running Module 10: Postinstall"
    module_10
}

main "$@"
