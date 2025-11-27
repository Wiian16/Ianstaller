#!/usr/bin/env bash

module_04() {
    # optimize pacman and makepkg
    info "Optimizing pacman and makepkg configs"

    # Enable parallel downloads, color, and multilib
    run_chroot sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
    run_chroot sed -i 's/^#Color/Color/' /etc/pacman.conf
    run_chroot sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
    run_chroot sed -i '/^\[multilib\]/{n;s/^#Include = /Include = /}' /etc/pacman.conf
    run_chroot pacman -Sy

    # Set makepkg and xz to use half of available threads
    local total_cores=$(nproc)
    local used_cores=$(((total_cores * 50 + 50) / 100))
    if [ "$used_cores" -lt 1 ]; then
        used_cores=1
    fi

    run_chroot sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$used_cores\"/" /etc/makepkg.conf
    run_chroot sed -i "s/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=$used_cores)/" /etc/makepkg.conf

    # Enable services
    info "Enabling services"
    run_chroot systemctl enable NetworkManager.service
    run_chroot systemctl enable systemd-timesyncd.service # Time synchronization

    # Configure UFW
    info "Configuring and enabling UFW"
    # Ensure IPv6 is disabled
    run sed -i 's/^IPV6=yes/IPV6=no/' /mnt/etc/ufw/ufw.conf
    append_if_missing 'IPV6=no' /mnt/etc/ufw/ufw.conf
    # Default to strict ufw rules
    run_chroot ufw default deny incoming
    run_chroot ufw default allow outgoing
    run_chroot systemctl enable ufw.service
}
