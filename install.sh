#!/usr/bin/env bash
# ========================================
# Ianstaller v2 -- Main Installer Entrypoint
# ========================================

set -Eeuo pipefail

# Source helper utilites and configuration
source ./config.sh
source ./modules/helpers.sh

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
    info "Skipping modules: ${SKIP_MODULES[*]:-(none)}"

    setup_config
    validate_config

    # Example: run modules conditionally
    for module in modules/*.sh; do
        module_name=$(basename "$module" .sh)
        if [[ " ${SKIP_MODULES[*]} " =~ " $module_name " ]]; then
            warn "Skipping module: $module_name"
            continue
        fi
        info "Running module: $module_name"
        source "$module"
    done
}

main "$@"
