#!/usr/bin/env bash

install_yay() {
    info "Installing yay AUR helper"

    run pacstrap /mnt base-devel git

    # Create a temporary user to build and install yay with passwordless privilege escalation
    run_chroot useradd -m -s /bin/bash aurbuild
    ensure_dir /mnt/etc/sudoers.d
    write_text "aurbuild ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers.d/aurbuild
    run_chroot chmod 440 /etc/sudoers.d/aurbuild

    run_chroot su - aurbuild -c '
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
'

    run rm -f /mnt/etc/sudoers.d/aurbuild
    run_chroot userdel -r aurbuild
}

install_nvidia_drivers() {
    error "Nvidia drivers not implemented yet"
    return 1
}

install_amd_drivers() {
    error "AMD drivers not implemented yet"
    return 1
}

install_intel_drivers() {
    error "Intel Drivers not implemented yet"
    return 1
}

install_video_drivers() {
    info "Detecting installed graphics cards"
    local intel_detected=$(lspci | grep -E "VGA|3D" | grep -qi intel && echo "true" || echo "false")
    local amd_detected=$(lspci | grep -E "VGA|3D" | grep -qi amd && echo "true" || echo "false")
    local nvidia_detected=$(lspci | grep -E "VGA|3D" | grep -qi nvidia && echo "true" || echo "false")

    if [ $nvidia_detected = "true" ]; then
        install_nvidia_drivers
    fi

    if [ $amd_detected = "true" ]; then
        install_amd_drivers
    fi

    if [ $intel_detected = "true" ]; then
        install_intel_drivers
    fi

    if [[ $nvidia_detected = "false" && $amd_detected = "false" && $intel_detected = "false" ]]; then
        info "No supported graphics cards detected, continuing"
    fi
}

module_04() {
    install_yay

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
    run_chroot systemctl enable bluetooth.service

    # Udiskie custom service
    ensure_dir /mnt/home/$USERNAME/.config/systemd/user

    run cp ./resources/udiskie.service /mnt/home/$USERNAME/.config/systemd/user/udiskie.service

    # Manually enable user systemd service
    ensure_dir /mnt/home/$USERNAME/.config/systemd/user/default.target.wants
    run ln -sf /mnt/home/$USERNAME/.config/systemd/user/udiskie.service /mnt/home/$USERNAME/.config/systemd/user/default.target.wants/udiskie.service

    # Configure UFW
    info "Configuring and enabling UFW"
    # Ensure IPv6 is disabled
    run sed -i 's/^IPV6=yes/IPV6=no/' /mnt/etc/ufw/ufw.conf
    append_if_missing 'IPV6=no' /mnt/etc/ufw/ufw.conf
    # Default to strict ufw rules
    run_chroot ufw default deny incoming
    run_chroot ufw default allow outgoing
    run_chroot systemctl enable ufw.service

    info "Installing Oh My ZSH for root user and regular user"

    # Run install scripts for regular user and root
    run_chroot sh -c "RUNZSH=no CHSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    run_chroot su - $USERNAME -c "RUNZSH=no CHSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    run_chroot chsh root -s /usr/bin/zsh
    run_chroot chsh $USERNAME -s /usr/bin/zsh

    install_video_drivers
}
