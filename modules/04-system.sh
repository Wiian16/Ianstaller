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
    info "Installing NVIDIA graphics drivers"
    run pacstrap -K /mnt ${VIDEO_DRIVERS_NVIDIA[@]}
    return 0
}

install_amd_drivers() {
    info "Installing AMD graphics drivers"
    run pacstrap -K /mnt ${VIDEO_DRIVERS_AMD[@]}
    return 0
}

install_intel_drivers() {
    info "Installing Intel graphics drivers"
    run pacstrap -K /mnt ${VIDEO_DRIVERS_INTEL[@]}
    return 0
}

install_video_drivers() {
    info "Detecting installed graphics cards"
    
    # Run lspci once
    local pci_output
    pci_output=$(lspci | grep -E "VGA|3D")

    # declaring local variables always returns exit code 0, seperate declaration from assignment
    local intel_detected amd_detected nvidia_detected
    echo "$pci_output" | grep -qi intel   && intel_detected=true   || intel_detected=false
    echo "$pci_output" | grep -qi amd     && amd_detected=true     || amd_detected=false
    echo "$pci_output" | grep -qi nvidia  && nvidia_detected=true  || nvidia_detected=false


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

install_cpu_microcode() {
        info "Detecting CPU vendor for microcode"
    
    local cpu_vendor
    cpu_vendor=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
    
    case "$cpu_vendor" in
        GenuineIntel)
            info "Installing Intel microcode"
            run pacstrap -K /mnt intel-ucode
            ;;
        AuthenticAMD)
            info "Installing AMD microcode"
            run pacstrap -K /mnt amd-ucode
            ;;
        *)
            info "Unknown CPU vendor '$cpu_vendor', skipping microcode"
            return 0
            ;;
    esac

    info Re-generating grub config to pick up microcode
    run_chroot grub-mkconfig -o /boot/grub/grub.cfg
}

setup_timers() {
    info "Setting up systemd timers"

    info "Enabling reflector timer"
    ensure_dir /mnt/etc/systemd/system/timers.target.wants
    ensure_dir /etc/xdg/reflector
    run cp ./resources/reflector.conf /mnt/etc/xdg/reflector
    run ln -sf /mnt/usr/lib/systemd/system/reflector.timer /mnt/etc/systemd/system/timers.target.wants/reflector.timer
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
    run_chroot su -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    run_chroot su - $USERNAME -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'

    run_chroot chsh root -s /usr/bin/zsh
    run_chroot chsh $USERNAME -s /usr/bin/zsh

    install_video_drivers

    install_cpu_microcode

    setup_timers
}
