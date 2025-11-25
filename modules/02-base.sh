#!/usr/bin/env bash

module_02() {
    # Run pacstrap
    info "Running pacstrap to install base system"
    run pacstrap -K /mnt ${PACKAGES_CORE[@]}

    # Generate fstab entries
    info "Generating fstab entries"
    run genfstab -U /mnt >>/mnt/etc/fstab
}
