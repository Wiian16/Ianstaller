#!/usr/bin/env bash

module_01() {
    # Mount root partition
    info "Mounting root partition"
    run mount $ROOT_PARTITION /mnt
    # Create btrfs subvolumes
    info "Creating btrfs subvolumes"

    run btrfs subvolume create /mnt/@
    run btrfs subvolume create /mnt/@home
    run btrfs subvolume create /mnt/@var_log
    run btrfs subvolume create /mnt/@snapshots

    info "Unmounting root partition"
    run umount /mnt

    # Mount subvolumes in correct locations
    info "Mounting subvolumes to correct locations"

    run mount -o compress=zstd,subvol=@ $ROOT_PARTITION /mnt
    ensure_dir /mnt/home
    run mount -o compress=zstd,subvol=@home $ROOT_PARTITION /mnt/home
    ensure_dir /mnt/var/log
    run mount -o compress=zstd,subvol=@var_log $ROOT_PARTITION /mnt/var/log
    ensure_dir /mnt/.snapshots
    run mount -o compress=zstd,subvol=@snapshots $ROOT_PARTITION /mnt/.snapshots

    info "Finished creating subvolume structure"

    info "Mounting EFI partition"

    if [[ $INSTALL_TYPE == "drive" ]]; then
        ensure_dir /mnt/boot/efi
        run mount $EFI_PARTITION /mnt/boot/efi
    fi
}
