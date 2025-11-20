#!/usr/bin/env bash

# Setup disk or partition for installation

partition_disk() {
    warn "Beginning disk partition, this will erase ALL data on the disk"
    if ! confirm; then
        exit 1
    fi

    info "Formatting drive "

    run parted /dev/"$INSTALL_LOCATION" --script mklabel gpt
    run parted /dev/"$INSTALL_LOCATION" --script mkpart ESP fat32 1MiB 1GiB
    run parted /dev/"$INSTALL_LOCATION" --script set 1 boot on
    run parted /dev/"$INSTALL_LOCATION" --script mkpart primary btrfs 1GiB 100%
}

partition_part() {
    error "Function not implemented yet"
    return 1
}

module_00() {
    case $INSTALL_TYPE in
    drive)
        partition_disk
        ;;
    partition)
        partition_part
        ;;
    *)
        error "Internal error: bad install location in module 0 ($INSTALL_TYPE)"
        false
        ;;
    esac
}
