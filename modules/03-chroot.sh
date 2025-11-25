#!/usr/bin/env bash

module_03() {
    info "Starting chroot configuration"

    # Configure timezone
    run_chroot ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime

    # Sync system time to the hardware clock
    run_chroot hwclock --systohc

    # Set locale and keyboard settings
    write_text "LANG=$LOCALE" /mnt/etc/locale.conf
    write_text "KEYMAP=us" /mnt/etc/vconsole.conf # TODO: Create a config option for this
    run_chroot locale-gen

    # Set device hostname
    run_chroot bash -c 'echo "$HOSTNAME" >/etc/hostname'

    # Setup hosts
    append_if_missing "127.0.0.1 localhost" /mnt/etc/hosts
    append_if_missing ":11       localhost" /mnt/etc/hosts
    append_if_missing "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" /mnt/etc/hosts

    # Setup root password
    run_chroot bash -c "echo 'root:$PASSWORD' | chpasswd"

    # Setup regular user password and sudo access
    run_chroot useradd -mG wheel $USERNAME
    run_chroot bash -c "echo '$USERNAME:$PASSWORD' | chpasswd"

    # Install grub (only for drive installs)
    if [[ "$INSTALL_TYPE" == "drive" ]]; then
        info "Installing and configuring bootloader"
        run_chroot grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi # TODO: add removable support

        # Enable os-prober
        ensure_dir /etc/default
        run_chroot sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

        # Make grub config
        ensure_dir /boot/grub
        run_chroot grub-mkconfig -o /boot/grub/grub.cfg

        # Verify UEFI boot entries
        run_chroot efibootmgr -v

        if ! run_chroot efibootmgr -v | grep -q "GRUB"; then
            warn "Creating UEFI boot entry for GRUB"
            arch-chroot /mnt efibootmgr --create --disk /dev/"$DEVICE" --part 1 --label "GRUB" --loader /EFI/GRUB/grubx64.efi
        fi
    else
        info "Skipping bootloading installation for partition install"
    fi
}
