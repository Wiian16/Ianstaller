#!/usr/bin/env bash

# Setup disk or partition for installation

partition_disk() {
    warn "Beginning disk partition, this will erase ALL data on the disk"
    if ! confirm; then
        exit 1
    fi

    info "Formatting drive"

    # Create partition table and partitions
    run parted /dev/"$INSTALL_LOCATION" --script mklabel gpt
    run parted /dev/"$INSTALL_LOCATION" --script mkpart ESP fat32 1MiB 1GiB
    run parted /dev/"$INSTALL_LOCATION" --script set 1 boot on
    run parted /dev/"$INSTALL_LOCATION" --script mkpart primary btrfs 1GiB 100%

    local efi_partition
    local root_partition

    # Set efi and root partition names
    if [[ $INSTALL_LOCATION == "nvme*" ]]; then
        efi_partition="/dev/${INSTALL_LOCATION}p1"
        root_partition="/dev/${INSTALL_LOCATION}p2"
    else
        efi_partition="/dev/${INSTALL_LOCATION}1"
        root_partition="/dev/${INSTALL_LOCATION}2"
    fi

    info "Created EFI parititon at $efi_partition"
    info "Created root partition at $root_partition"

    # Format partitions
    info "Formatting partitions"
    run mkfs.fat -F32 "$efi_partition"
    # TODO: may not need to format btrfs, seems to be done by parted (added -f flag to avoid error)
    run mkfs.btrfs -f "$root_partition"

    # Mount partitions
    info "Mounting partitions"

    run ensure_dir /mnt/boot/efi

    run mount "$root_partition" /mnt
    run mount "$efi_partition" /mnt/boot/efi
}

partition_part() {
    warn "Beginning partition format, this will erase ALL data on the partition"

    if ! confirm; then
        exit
    fi

    info "Formatting partition"

    local part_location="/dev/${INSTALL_LOCATION}"

    # Format partition
    run mkfs.btrfs -f "$part_location"

    info "Mounting partition"

    run ensure_dir /mnt

    run mount "$part_location" /mnt
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
