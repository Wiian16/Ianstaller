#!/bin/bash

set -e
set -o pipefail

# === Setup === #

# Set up logging
exec > >(tee ianstaller.log)
exec 2>&1

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BRIGHT_BLUE='\033[1;34m' # Bright Blue
BOLD_BRIGHT_BLUE='\033[1;94m' # Bold and Bright Blue
NC='\033[0m' # No Color

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please run with sudo or as the root user.${NC}"
    exit 1
fi




# === Functions === #

# Function to validate timezone
validate_timezone() {
    local tz=$1
    if [ -f "/usr/share/zoneinfo/$tz" ]; then
        return 0
    else
        echo -e "${RED}Invalid timezone. Please enter a valid timezone.${NC}"
        return 1
    fi
}

# Function to validate username
validate_username() {
    local re='^[a-z_][a-z0-9_-]*[$]?$'
    if [[ $1 =~ $re ]] && [ ${#1} -le 32 ]; then
        return 0
    else
        echo -e "${RED}Invalid username. Please enter a valid username.${NC}"
        return 1
    fi
}

# Function to validate device
validate_device() {
    if [ -b "/dev/$1" ]; then
        return 0
    else
        echo -e "${RED}Invalid device. Please enter a valid device.${NC}"
        return 1
    fi
}

# Function to validate hostname
validate_hostname() {
    local re='^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$'
    if [[ $1 =~ $re ]]; then
        return 0
    else
        echo -e "${RED}Invalid hostname. Please enter a valid hostname.${NC}"
        return 1
    fi
}

# Function to get the available disk space in GiB
get_available_disk_space() {
    local device=$1
    local available_space=$(lsblk -brndo SIZE "/dev/$device" | awk '{print int($1/1024/1024/1024)}') # Convert bytes to GiB
    echo $available_space
}


# Function to list devices
list_devices() {
    echo -e "${YELLOW}Available devices:${NC}"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL -d | awk 'NR>1 {print}'
}


# === Cleanup Functions === #

finishing-cleanup() {
    echo -e "${BRIGHT_BLUE}Syncing...${NC}"
    sync # Flush filesystem buffers
    sleep 5 # Give some time for the buffers to flush
    
    # Unmount partitions in reverse order of mounting
    echo -e "${BRIGHT_BLUE}Unmounting efi...${NC}"
    umount /mnt/boot/efi || true
    
    # Optionally deactivate swap if it was activated
    echo -e "${BRIGHT_BLUE}Deactivating Swap...${NC}"
    swapoff /mnt/swapfile || true
    sleep 2
    
    # Unbind /lib/modules if it was bound
    echo -e "${BRIGHT_BLUE}Unmounting Modules...${NC}"
    umount /mnt/lib/modules > /dev/null 2>&1 || true
    sleep 1
    
    echo -e "${BRIGHT_BLUE}Killing Processes...${NC}"
    fuser -km /mnt || true
    sleep 2
    
    echo -e "${BRIGHT_BLUE}Final Unmount...${NC}"
    umount -R /mnt || true
}

error-cleanup(){
    echo -e "${RED}Error detected, cleaning up...${NC}"
    
    sync # Flush filesystem buffers
    sleep 5 # Give some time for the buffers to flush
    
    # Unmount partitions in reverse order of mounting
    umount /mnt/boot/efi || true
    
    # Optionally deactivate swap if it was activated
    swapoff /mnt/swapfile || true
    sleep 2
    
    # Unbind /lib/modules if it was bound
    umount /mnt/lib/modules || true
    
    fuser -km /mnt || true
    sleep 2
    
    umount -R /mnt || true
    
    echo -e "${RED}Cleanup complete. You may now attempt to rerun the script or perform manual fixes.${NC}"
}

trap error-cleanup ERR









# === System Config Input === #


# Clear the screen for a clean start
clear

# Display welcome message
echo -e "${GREEN}Wiian16's Custom Arch Linux Installer${NC}"
echo -e "${BRIGHT_BLUE}-------------------------------------------------${NC}"

# Ask for hostname with validation
while true; do
    read -p "Enter hostname: " HOSTNAME
    validate_hostname "$HOSTNAME" && break
done
echo

# Ask for timezone with validation
while true; do
    read -p "Enter timezone (e.g., America/New_York): " TIMEZONE
    validate_timezone "$TIMEZONE" && break
done
echo

# Ask for username with validation
while true; do
    read -p "Enter new user name: " USER_NAME
    validate_username "$USER_NAME" && break
done
echo

# Ask for password using the -s flag to hide input and validate by asking to enter it twice
while true; do
    read -sp "Enter password for the new user (will also be root password): " USER_PASSWORD
    echo
    read -sp "Re-enter password to confirm: " USER_PASSWORD_CONFIRM
    echo
    if [ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]; then
        break
    else
        echo -e "${RED}Passwords do not match. Please try again.${NC}"
    fi
done
echo

echo -e "${BRIGHT_BLUE}===============================================${NC}"
echo
list_devices
echo
echo -e "${BRIGHT_BLUE}===============================================${NC}"
echo

# Ask for the device to install on with validation
while true; do
    read -p "Enter the device to install on (e.g., sda): " DEVICE
    validate_device "$DEVICE" && break
done

# Ask if the user is installing to a removable drive
read -p "Are you installing to a removable drive? (y/N): " REMOVABLE
if [[ $REMOVABLE =~ ^[yY]$ ]]; then
    REMOVABLE_FLAG="--removable"
    REMOVABLE_TEXT="Yes"
else
    REMOVABLE_FLAG=""
    REMOVABLE_TEXT="No"
fi

# Ask for the swap size with validation
while true; do
    read -p "Enter swap size in GiB (Default no swap): " SWAP_SIZE
    if [[ -z "$SWAP_SIZE" ]]; then
        SWAP_SIZE=0
        break
        elif [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]] && [ "$SWAP_SIZE" -ge 0 ]; then
        available_space=$(get_available_disk_space "$DEVICE")
        if [ "$SWAP_SIZE" -le "$available_space" ]; then
            break
        else
            echo -e "${RED}Invalid swap size. The size exceeds the available disk space of ${available_space}GiB.${NC}"
        fi
    else
        echo -e "${RED}Invalid swap size. Please enter a non-negative integer.${NC}"
    fi
done
echo

# Check if the device is an NVMe drive and construct partition names accordingly
if [[ $DEVICE == nvme* ]]; then
    EFI_PARTITION="/dev/${DEVICE}p1"
    ROOT_PARTITION="/dev/${DEVICE}p2"
else
    EFI_PARTITION="/dev/${DEVICE}1"
    ROOT_PARTITION="/dev/${DEVICE}2"
fi
echo


# Confirm with the user before proceeding
echo -e "${YELLOW}Installation Summary:${NC}"
echo "--------------------------------"
echo -e "${BRIGHT_BLUE}Hostname:${NC} $HOSTNAME"
echo -e "${BRIGHT_BLUE}Timezone:${NC} $TIMEZONE"
echo -e "${BRIGHT_BLUE}New user:${NC} $USER_NAME"
echo -e "${BRIGHT_BLUE}User password:${NC} (hidden)"
echo -e "${BRIGHT_BLUE}EFI Partition:${NC} $EFI_PARTITION"
echo -e "${BRIGHT_BLUE}Root Partition:${NC} $ROOT_PARTITION"
echo -e "${BRIGHT_BLUE}Removable Drive:${NC} $REMOVABLE_TEXT"
if [ "$SWAP_SIZE" -gt 0 ]; then
    echo -e "${BRIGHT_BLUE}Swap File Size:${NC} ${SWAP_SIZE}GiB"
else
    echo -e "${BRIGHT_BLUE}Swap:${NC} No swap file"
fi
echo "--------------------------------"
read -p "Are you sure you want to proceed? (y/N): " CONFIRM
if [[ $CONFIRM != [yY] ]]; then
    echo -e "${RED}Installation aborted by user.${NC}"
    exit 1
fi









# === Level 0 Installation === #

# Modify pacman.conf on Arch ISO
echo -e "${BOLD_BRIGHT_BLUE}Modifying pacman.conf on Arch ISO...${NC}"
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf
echo -e "${BOLD_BRIGHT_BLUE}Enabled parallel downloads and color in pacman.conf on Arch ISO.${NC}"
echo



# Update make configuration

# Calculate 50% of available CPU cores using shell arithmetic
total_cores=$(nproc)
used_cores=$(( (total_cores * 50 + 50) / 100 ))  # This rounds to the nearest integer

# Ensure at least one core is used
if [ "$used_cores" -lt 1 ]; then
    used_cores=1
fi

# Optimize makepkg.conf
echo -e "${BOLD_BRIGHT_BLUE}Optimizing makepkg.conf...${NC}"
sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$used_cores\"/" /etc/makepkg.conf
sed -i "s/^#COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=$used_cores)/" /etc/makepkg.conf



# Partition the disk
echo -e "${BOLD_BRIGHT_BLUE}Partitioning the disk...${NC}"
parted /dev/"$DEVICE" --script mklabel gpt
parted /dev/"$DEVICE" --script mkpart ESP fat32 1MiB 513MiB
parted /dev/"$DEVICE" --script set 1 boot on
parted /dev/"$DEVICE" --script mkpart primary ext4 513MiB 100%


# Format the partitions
echo -e "${BOLD_BRIGHT_BLUE}Formatting the partitions...${NC}"
mkfs.fat -F32 "$EFI_PARTITION"
mkfs.ext4 "$ROOT_PARTITION"


# Mount the partitions
echo -e "${BOLD_BRIGHT_BLUE}Mounting the partitions...${NC}"
mount "$ROOT_PARTITION" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PARTITION" /mnt/boot/efi


# Install essential packages
echo -e "${BOLD_BRIGHT_BLUE}Installing essential packages...${NC}"
pacstrap /mnt base linux linux-firmware linux-headers grub efibootmgr os-prober zsh curl wget git nano


# Configure the system
echo -e "${BOLD_BRIGHT_BLUE}Configuring the system...${NC}"

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc

echo "$HOSTNAME" > /mnt/etc/hostname

# Set the locale to en_US.UTF-8
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot /mnt echo "LANG=en_US.UTF-8" > /etc/locale.conf
arch-chroot /mnt locale-gen

echo "KEYMAP=us" > /mnt/etc/vconsole.conf
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /mnt/etc/hosts
echo root:"$USER_PASSWORD" | chpasswd --root /mnt
arch-chroot /mnt chsh -s /bin/zsh root


# Install and configure the bootloader
echo -e "${BOLD_BRIGHT_BLUE}Installing and configuring the bootloader...${NC}"
arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi $REMOVABLE_FLAG

# Enable os-prober in GRUB configuration
echo -e "${BOLD_BRIGHT_BLUE}Enabling os-prober in GRUB configuration...${NC}"
arch-chroot /mnt sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Verify UEFI boot entries
echo -e "${BOLD_BRIGHT_BLUE}Verifying UEFI boot entries...${NC}"
arch-chroot /mnt efibootmgr -v

# If GRUB entry is missing, create it manually
if ! arch-chroot /mnt efibootmgr -v | grep -q "GRUB"; then
    echo -e "${BOLD_BRIGHT_BLUE}Creating UEFI boot entry for GRUB...${NC}"
    arch-chroot /mnt efibootmgr --create --disk /dev/"$DEVICE" --part 1 --label "GRUB" --loader /EFI/GRUB/grubx64.efi
fi

# Modify pacman.conf on the new system
echo -e "${BOLD_BRIGHT_BLUE}Modifying pacman.conf on the new system...${NC}"
arch-chroot /mnt sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
arch-chroot /mnt sed -i 's/^#Color/Color/' /etc/pacman.conf
arch-chroot /mnt sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
arch-chroot /mnt sed -i '/^\[multilib\]/{n;s/^#Include = /Include = /}' /etc/pacman.conf
arch-chroot /mnt pacman -Sy
echo -e "${GREEN}Enabled parallel downloads, multilib, and color in pacman.conf on the new system.${NC}"
echo


# Optimize makepkg.conf on the newly installed system
echo -e "${BOLD_BRIGHT_BLUE}Optimizing makepkg.conf on the newly installed system...${NC}"
arch-chroot /mnt sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$used_cores\"/" /etc/makepkg.conf
arch-chroot /mnt sed -i "s/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=$used_cores)/" /etc/makepkg.conf


# Optimize disk I/O for SSD on the newly installed system
echo -e "${BOLD_BRIGHT_BLUE}Optimizing disk I/O for SSD on the newly installed system...${NC}"
arch-chroot /mnt bash -c 'echo "vm.swappiness=10" >> /etc/sysctl.d/99-sysctl.conf'







# === Level 1 Installation

# Create a user account
echo -e "${BOLD_BRIGHT_BLUE}Creating user account...${NC}"
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh "$USER_NAME"
echo "$USER_NAME:$USER_PASSWORD" | chpasswd --root /mnt


# Set up sudo
echo "Setting up sudo..."
# Install sudo if it's not already installed
arch-chroot /mnt pacman -S --noconfirm sudo
# Uncomment to allow members of group wheel to execute any command
#arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
#echo "%wheel ALL=(ALL:ALL) ALL" | arch-chroot /mnt tee -a /etc/sudoers > /dev/null

# Set up a swap file
if [ "$SWAP_SIZE" -gt 0 ]; then
    echo -e "${BOLD_BRIGHT_BLUE}Setting up swap file...${NC}"
    arch-chroot /mnt fallocate -l "${SWAP_SIZE}G" /swapfile
    arch-chroot /mnt chmod 600 /swapfile
    arch-chroot /mnt mkswap /swapfile
    arch-chroot /mnt swapon /swapfile
    echo '/swapfile none swap defaults 0 0' >> /mnt/etc/fstab
fi

# Install and enable NetworkManager
echo -e "${BOLD_BRIGHT_BLUE}Installing and enabling NetworkManager...${NC}"
arch-chroot /mnt pacman -S --noconfirm networkmanager
arch-chroot /mnt systemctl enable NetworkManager


# Enable systemd-timesyncd for time synchronization
echo -e "${BOLD_BRIGHT_BLUE}Enabling systemd-timesyncd for time synchronization...${NC}"
arch-chroot /mnt systemctl enable systemd-timesyncd.service


# Create the /mnt/lib/modules directory
mkdir -p /mnt/lib/modules
mount --bind /lib/modules /mnt/lib/modules

# Install and setup UFW
echo -e "${BOLD_BRIGHT_BLUE}Installing and setting up UFW (Uncomplicated Firewall)...${NC}"
arch-chroot /mnt pacman -S --noconfirm ufw
# Enable basic firewall rules (deny incoming, allow outgoing)
arch-chroot /mnt ufw default deny incoming
arch-chroot /mnt ufw default allow outgoing
# Enable the firewall
arch-chroot /mnt ufw enable
# Enable UFW to start on boot
arch-chroot /mnt systemctl enable ufw
# Unbind /lib/modules after setting up UFW and before enabling any services
umount /mnt/lib/modules




# === Level 2 Installation === #

# = Oh My Zsh = #

# Install Oh My Zsh for the root user without changing the shell or running Zsh
echo -e "${BOLD_BRIGHT_BLUE}Installing Oh My Zsh for the root user...${NC}"
arch-chroot /mnt sh -c "RUNZSH=no CHSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Oh My Zsh for the new user without changing the shell or running Zsh
echo -e "${BOLD_BRIGHT_BLUE}Installing Oh My Zsh for the new user...${NC}"
arch-chroot /mnt su - "$USER_NAME" -c "RUNZSH=no CHSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Create the custom theme directory for the root user
arch-chroot /mnt mkdir -p /root/.oh-my-zsh/custom/themes

# Create the custom theme directory for the new user
arch-chroot /mnt mkdir -p /home/"$USER_NAME"/.oh-my-zsh/custom/themes

# Ensure the new user owns their home directory and contents
arch-chroot /mnt chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"


# = Yay = #

# Install Yay AUR Helper
echo -e "${BOLD_BRIGHT_BLUE}Installing Yay AUR Helper...${NC}"
arch-chroot /mnt pacman -S --needed --noconfirm git base-devel go
arch-chroot /mnt su - "$USER_NAME" -c "bash -c '\
    mkdir -p ~/yay_build && \
    git clone https://aur.archlinux.org/yay.git ~/yay_build/yay && \
    cd ~/yay_build/yay && \
    makepkg --noconfirm \
'"
# Use find to locate the package file and install it
arch-chroot /mnt bash -c "pacman -U \$(find /home/$USER_NAME/yay_build/yay -name 'yay-*.pkg.tar.zst') --noconfirm"
arch-chroot /mnt rm -rf /home/"$USER_NAME"/yay_build

# = TLP = #

# Install TLP for power management
echo -e "${BOLD_BRIGHT_BLUE}Installing TLP for power management...${NC}"
arch-chroot /mnt pacman -S --noconfirm tlp tlp-rdw

# Enable TLP services
echo -e "${BOLD_BRIGHT_BLUE}Enabling TLP services...${NC}"
arch-chroot /mnt systemctl enable tlp.service







# === Level 3 Installation === #

# = Graphics Drivers = #
# Check if lspci is available
if ! command -v lspci &> /dev/null; then
    echo -e "${BOLD_BRIGHT_BLUE}lspci command not found. Installing pciutils...${NC}"
    arch-chroot /mnt pacman -S --noconfirm pciutils
fi

# Detect and install graphics drivers
echo -e "${BOLD_BRIGHT_BLUE}Detecting and installing graphics drivers...${NC}"

# Detect Intel, AMD, and NVIDIA graphics
intel_detected=$(lspci | grep -E "VGA|3D" | grep -qi intel && echo "yes" || echo "no")
amd_detected=$(lspci | grep -E "VGA|3D" | grep -qi amd && echo "yes" || echo "no")
nvidia_detected=$(lspci | grep -E "VGA|3D" | grep -qi nvidia && echo "yes" || echo "no")

# Install NVIDIA drivers if NVIDIA graphics are detected (regardless of Intel)
if [ "$nvidia_detected" = "yes" ]; then
    echo -e "${BOLD_BRIGHT_BLUE}NVIDIA graphics detected. Installing NVIDIA drivers...${NC}"
    arch-chroot /mnt pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
    
    # Add nvidia_drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT
    echo -e "${BOLD_BRIGHT_BLUE}Configuring GRUB for NVIDIA...${NC}"
    if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT' /mnt/etc/default/grub; then
        arch-chroot /mnt sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 nvidia_drm.modeset=1"/' /etc/default/grub
    else
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet nvidia_drm.modeset=1"' | arch-chroot /mnt tee -a /etc/default/grub > /dev/null
    fi
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    
    # Add NVIDIA modules to mkinitcpio.conf
    echo -e "${BOLD_BRIGHT_BLUE}Adding NVIDIA modules to initramfs...${NC}"
    if grep -q '^MODULES=' /mnt/etc/mkinitcpio.conf; then
        arch-chroot /mnt sed -i '/^MODULES=(/s/)$/ nvidia nvidia_modeset nvidia_uvm nvidia_drm&/' /etc/mkinitcpio.conf
    else
        echo 'MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)' | arch-chroot /mnt tee -a /etc/mkinitcpio.conf > /dev/null
    fi
    arch-chroot /mnt mkinitcpio -P
    
    # Install Intel drivers only if Intel is detected and NVIDIA is not
    elif [ "$intel_detected" = "yes" ]; then
    echo -e "${BOLD_BRIGHT_BLUE}Intel graphics detected. Installing Intel drivers...${NC}"
    read -p "Install Intel video drivers? (Only affects Intel machines) (Y/n): " CONFIRM
    if [[ $CONFIRM != [nN] ]]; then
        arch-chroot /mnt pacman -S --noconfirm xf86-video-intel
    fi
    # Install AMD drivers if AMD graphics are detected
    elif [ "$amd_detected" = "yes" ]; then
    echo -e "${BOLD_BRIGHT_BLUE}AMD graphics detected. Installing AMD drivers...${NC}"
    arch-chroot /mnt pacman -S --noconfirm xf86-video-amdgpu
fi


# = Micro Code = #

# Detect and install CPU microcode
echo -e "${BOLD_BRIGHT_BLUE}Detecting and installing CPU microcode...${NC}"

# Detect Intel CPU
if grep -qi intel /proc/cpuinfo; then
    echo -e "${BOLD_BRIGHT_BLUE}Intel CPU detected. Installing microcode...${NC}"
    arch-chroot /mnt pacman -S --noconfirm intel-ucode
fi

# Detect AMD CPU
if grep -qi amd /proc/cpuinfo; then
    echo -e "${BOLD_BRIGHT_BLUE}AMD CPU detected. Installing microcode...${NC}"
    arch-chroot /mnt pacman -S --noconfirm amd-ucode
fi



# = Audio = #

# Install audio packages
echo -e "${BOLD_BRIGHT_BLUE}Installing audio packages...${NC}"
arch-chroot /mnt pacman -S --noconfirm pulseaudio pulseaudio-alsa alsa-utils pavucontrol

# Install Bluetooth packages
echo -e "${BOLD_BRIGHT_BLUE}Installing Bluetooth packages...${NC}"
arch-chroot /mnt pacman -S --noconfirm bluez bluez-utils



# = Bluetooth = #

# Enable the Bluetooth service
echo -e "${BOLD_BRIGHT_BLUE}Enabling Bluetooth service...${NC}"
arch-chroot /mnt systemctl enable bluetooth.service

# Install and enable additional Bluetooth tools and services
arch-chroot /mnt pacman -S --noconfirm pulseaudio-bluetooth blueman



# = Udiskie = #

echo -e "${BOLD_BRIGHT_BLUE}Setting up udiskie...${NC}"

# arch-chroot /mnt pacman -S --needed --noconfirm udiskie

# Create the user's systemd directory if it doesn't exist
arch-chroot /mnt mkdir -p /home/$USER_NAME/.config/systemd/user

# Create and enable udiskie service for automounting USB drives as a user service
# arch-chroot /mnt /bin/bash -c "cat > /home/$USER_NAME/.config/systemd/user/udiskie.service <<EOF
# [Unit]
# Description=Automount USB drives with udiskie
#
# [Service]
# Type=simple
# ExecStart=/usr/bin/udiskie -a
#
# [Install]
# WantedBy=default.target
# EOF"

# Ensure the correct permissions are set for the user's systemd directory and service file
arch-chroot /mnt chown -R $USER_NAME: /home/$USER_NAME/.config/systemd

# Enable the udiskie service for the user so it starts on login
# arch-chroot /mnt su - "$USER_NAME" -c "systemctl --user enable udiskie.service"










# === Level 4 Installation === #

echo -e "${YELLOW}Temporarily making sudo passwordless${NC}"

# Backup the original sudoers file
arch-chroot /mnt cp /etc/sudoers /etc/sudoers.bak

# Add the user to the sudoers file with NOPASSWD
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" | arch-chroot /mnt tee /etc/sudoers.d/$USER_NAME


# Define an array of packages to install
PACKAGES=(
    
    # Xorg
    xorg-server xorg-xinit xorg-apps xorg-xrandr xorg-xsetroot xorg-xbacklight xsettingsd
    
    bspwm sxhkd        # Window manager and hotkeys
    sddm               # Display manager
    thunar             # GUI file manager
    alacritty          # GPU terminal
    polybar            # Info-bar at top
    picom              # Compositor (blur, shadows, vsync, etc...)
    dunst              # Notification display
    lxappearance       # Change themes, icons, fonts, and cursors
    
    # Fonts
    ttf-dejavu ttf-liberation noto-fonts ttf-jetbrains-mono-nerd ttf-jetbrains-mono noto-fonts-cjk
    
    # Desktop Depends
    rofi                               # Rofi menues
    feh viewnior                       # View Images
    copyq                              # Clipboard manager/history
    alsa-utils pulseaudio playerctl    # Audio
    arandr                             # GUI display manager
    neovim ranger htop fastfetch gdu   # Terminal Applications
    rofi-calc                          # Calculator
    sed jq imagemagick pastel          # Dependencies for theme script
    file-roller tumbler xarchiver      # Thunar extentions, archiver
    ffmpegthumbnailer gst-libav        # More Thunar extentions
    xcolor                             # Color Picker
    xdotool maim xclip                 # Screen Shots
    pulsemixer                         # Audio control
    bc                                 # Command line calculations
    
    # System Packages
    gnome-keyring libsecret   # Applications to store passwords/data
    qt5                       # Required dependency
    tree                      # Terminal tree view
    papirus-icon-theme xapp   # Icons for rofi and applications
    noto-fonts-emoji          # Emojis
    xdg-user-dirs             # Generate and assign home directories
    udiskie                   # Auto mounnt USBs
    man                       # For help instructions
    gparted                   # For formating etc..
    github-cli                # For Github to save your credentials
    gvfs                      # For thunar's trash and OS volumes
    reflector                 # For Updating mirror list
    man-pages                 # For help instructions
    
    # Applications
    mpv         # Minimal Video Player
    vlc         # Multi-Video formater and playback
    gimp        # Image editor
    discord     # ... discord
    obs-studio  # Recording Videos
    btop        # Monitoring System Resources
    zoxide      # cd Autocompletion
    sl          # ...
    obsidian	# Note Taking
    firefox     # Web Browsing
    inkscape	# Vector Image Editor
    libreoffice-fresh  # Rich Text Editor Suite
    atril       # PDF Viewer
    bitwarden   # Password Manager
    vlc         # Video Player
    github-cli  # Github Credential Manager
    samba       # Samba client for network shares
    fzf         # Fuzzy searcher
    npm         # Node.js 

    # For Sddm Theme
    qt6-5compat qt6-declarative qt6-svg
)

AUR_PACKAGES=(
    ksuperkey               # Superkey launches rofi menu
    xfce-polkit             # Agent for handling permissions
    python-pywal            # Generate color schemes for theme script
    nordic-darker-theme     # GTK theme
    i3lock-color            # Lock dependency takes in colors
    i3lock-fancy-rapid-git  # Blur lock screen
    qt5-styleplugins        # Copies GTK theme to qt
    
    # Applications
    google-chrome           # Web browser
    visual-studio-code-bin  # Code and Text editor
    zoom                    # Meeting Software
    #backlight_control       # Control backlight
    nvim-lazy               # Neovim lazy package manager
)


# Install all packages in the array
echo -e "${BOLD_BRIGHT_BLUE}Installing packages...${NC}"
arch-chroot /mnt pacman -S --noconfirm --needed "${PACKAGES[@]}"

# Install all AUR packages in the array
echo -e "${BOLD_BRIGHT_BLUE}Installing AUR packages...${NC}"
arch-chroot /mnt su - "$USER_NAME" -c "yay -S --needed --noconfirm ${AUR_PACKAGES[*]}"

# Enable SDDM
echo -e "${BOLD_BRIGHT_BLUE}Enabling SDDM...${NC}"
arch-chroot /mnt systemctl enable sddm.service

# Clone the user's dotfiles repository
echo -e "${BOLD_BRIGHT_BLUE}Cloning the user's dotfiles repository...${NC}"
arch-chroot /mnt su - "$USER_NAME" -c "git clone https://github.com/Wiian16/DotFiles.git /home/$USER_NAME/.dotfiles"


# === Apply Dotfiles === #

# Ensure the new user owns their home directory and contents
arch-chroot /mnt chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"

# Define the user's home directory
USER_HOME="/home/$USER_NAME"

# Define the dotfiles directory
DOTFILES_DIR="$USER_HOME/.dotfiles"

# Function to copy dotfiles to the appropriate location
copy_dotfiles() {
    local src=$1
    local dest=$2
    arch-chroot /mnt su - "$USER_NAME" -c "mkdir -p \"$dest\""
    arch-chroot /mnt su - "$USER_NAME" -c "cp -ar \"$src\"/* \"$dest\"/"
}

# Copy the main configuration files
copy_dotfiles "$DOTFILES_DIR/alacritty" "$USER_HOME/.config/alacritty"
copy_dotfiles "$DOTFILES_DIR/bspwm" "$USER_HOME/.config/bspwm"
copy_dotfiles "$DOTFILES_DIR/dunst" "$USER_HOME/.config/dunst"
copy_dotfiles "$DOTFILES_DIR/fastfetch" "$USER_HOME/.config/fastfetch"
copy_dotfiles "$DOTFILES_DIR/picom" "$USER_HOME/.config/picom"
copy_dotfiles "$DOTFILES_DIR/polybar" "$USER_HOME/.config/polybar"
copy_dotfiles "$DOTFILES_DIR/sxhkd" "$USER_HOME/.config/sxhkd"
copy_dotfiles "$DOTFILES_DIR/Thunar" "$USER_HOME/.config/Thunar"
copy_dotfiles "$DOTFILES_DIR/Lazy" "$USER_HOME/.config/Lazy"

# Nanorc
arch-chroot /mnt cp "$DOTFILES_DIR/.nanorc" "$USER_HOME/.nanorc"

# Discord fix
arch-chroot /mnt mkdir -p "$USER_HOME/.config/discord/"
arch-chroot /mnt cp "$DOTFILES_DIR/discord-update-fix.json" "$USER_HOME/.config/discord/."

# Custom zsh theme
arch-chroot /mnt cp "$DOTFILES_DIR/archcraft.zsh-theme" "$USER_HOME/.oh-my-zsh/custom/themes/"

# Handle Theme
arch-chroot /mnt cp -r "$DOTFILES_DIR/Nordic-Cursors" "/usr/share/icons"
arch-chroot /mnt cp -r "$DOTFILES_DIR/Nordic-Folders" "/usr/share/icons"
arch-chroot /mnt cp "$DOTFILES_DIR/.theme" "$USER_HOME"

# User GTK
arch-chroot /mnt mkdir "$USER_HOME/.config/gtk-3.0"
arch-chroot /mnt cp "$DOTFILES_DIR/gtk-3.0/settings.ini" "$USER_HOME/.config/gtk-3.0"
arch-chroot /mnt cp "$DOTFILES_DIR/.gtkrc-2.0" "$USER_HOME"

# Root GTK
arch-chroot /mnt mkdir -p "/root/.config/gtk-3.0"
arch-chroot /mnt cp "$DOTFILES_DIR/gtk-3.0/settings.ini" "/root/.config/gtk-3.0"
arch-chroot /mnt cp "$DOTFILES_DIR/.gtkrc-2.0" "/root"


# QT Theming
arch-chroot /mnt /bin/bash -c "cat >> /etc/environment << 'EOF'
QT_QPA_PLATFORMTHEME=gtk2
QT_STYLE_OVERRIDE=gtk2
EOF"

# Handle Pictures
arch-chroot /mnt su - "$USER_NAME" -c "cp -r \"$DOTFILES_DIR/Pictures\" \"$USER_HOME\""

# Create .fehbg file and make it executable
arch-chroot /mnt su - "$USER_NAME" -c "echo -e '#!/bin/sh\nfeh --no-fehbg --bg-fill '\''/home/$USER_NAME/Pictures/Wallpapers/ZenWhiteFlower_AnnieSpratt.jpg'\''' > \"$USER_HOME/.fehbg\" && chmod +x \"$USER_HOME/.fehbg\""

# Handle fonts
arch-chroot /mnt /bin/bash -c "cp \"$DOTFILES_DIR\"/fonts/* /usr/share/fonts/"
arch-chroot /mnt fc-cache -fv

# Handle X11 configuration
arch-chroot /mnt mkdir -p "/etc/X11/xorg.conf.d"
arch-chroot /mnt /bin/bash -c "cp -r \"$DOTFILES_DIR\"/X11/* /etc/X11/xorg.conf.d/"

# Handle SDDM theme
SDDM_THEME_NAME="sddm-blur-theme"
arch-chroot /mnt mkdir -p "/usr/share/sddm/themes/${SDDM_THEME_NAME}"
arch-chroot /mnt sh -c "cp -r '$DOTFILES_DIR/$SDDM_THEME_NAME/'* '/usr/share/sddm/themes/${SDDM_THEME_NAME}/'"
arch-chroot /mnt sh -c "cp /usr/share/sddm/themes/$SDDM_THEME_NAME/Fonts/* /usr/share/fonts/"
arch-chroot /mnt sh -c "cp /usr/lib/sddm/sddm.conf.d/default.conf /etc/sddm.conf"

# Update SDDM configuration
if ! arch-chroot /mnt grep -q "\[Theme\]" /etc/sddm.conf; then
    arch-chroot /mnt bash -c "echo -e '\n[Theme]' >> /etc/sddm.conf"
fi

if ! arch-chroot /mnt grep -q "^Current=" /etc/sddm.conf; then
    arch-chroot /mnt sed -i "/^\[Theme\]/aCurrent=$SDDM_THEME_NAME" /etc/sddm.conf
else
    arch-chroot /mnt sed -i "s/^Current=.*/Current=$SDDM_THEME_NAME/" /etc/sddm.conf
fi


# Add Grub Theme
#echo -e "${BOLD_BRIGHT_BLUE}Installing Grub Theme...${NC}"
#arch-chroot /mnt unzip "$DOTFILES_DIR/grubtheme.zip" -d "$DOTFILES_DIR"
#arch-chroot /mnt cp -r "$DOTFILES_DIR/floralboot" "/boot/grub/themes/."
#arch-chroot /mnt bash -c 'echo GRUB_THEME=\"/boot/grub/themes/floralboot/theme.txt\" >> /etc/default/grub'
#arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg



# Add custom aliases and functions to .zshrc
arch-chroot /mnt su - "$USER_NAME" -c "cat >> \"$USER_HOME/.zshrc\" << 'EOF'

alias la=\"ls -a\"
alias neofetch=\"fastfetch\"
alias nf=\"clear && fastfetch\"
alias ff=\"fastfetch\"
alias cclear=\"sudo sh -c '/usr/bin/echo 3 > /proc/sys/vm/drop_caches'\"
alias nv=\"nvim\"
alias cls=\"clear\"

# Neovim switcher
function nvims() {
  items=(\"default\")
  config=\$(printf \"%s\n\" \"\${items[@]}\" | fzf --prompt=\" Neovim Config  \" --height=~50% --layout=reverse --border --exit-0)
  if [[ -z \$config ]]; then
    echo \"Nothing selected\"
    return 0
  elif [[ \$config == \"default\" ]]; then
    config=\"\"
  fi
  NVIM_APPNAME=\$config nvim \$@
}

# Setup zoxide for cd
eval \"\$(zoxide init zsh --cmd cd)\"
EOF"

# Change ZSH_THEME to "archcraft" in .zshrc
arch-chroot /mnt su - "$USER_NAME" -c "sed -i 's/^ZSH_THEME=\".*\"/ZSH_THEME=\"archcraft\"/' \"$USER_HOME/.zshrc\""

# Add Default Dirs
arch-chroot /mnt su - "$USER_NAME" -c "xdg-user-dirs-update"
arch-chroot /mnt rm -rf $USER_HOME/Public $USER_HOME/Templates $USER_HOME/.zcompdump-* $USER_HOME/.bashrc $USER_HOME/.bash_logout $USER_HOME/.bash_profile $USER_HOME/.dotfiles

# Remove Garbage Apps
arch-chroot /mnt rm /usr/share/applications/avahi-discover.desktop /usr/share/applications/bssh.desktop /usr/share/applications/bvnc.desktop /usr/share/applications/xfce4-about.desktop /usr/share/applications/thunar-bulk-rename.desktop /usr/share/applications/thunar-settings.desktop

# Ensure the new user owns their home directory and contents
arch-chroot /mnt chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"

# Update Reflectors
echo -e "${BOLD_BRIGHT_BLUE}Updating Reflectors...${NC}"
arch-chroot /mnt pacman -S --noconfirm --needed reflector
arch-chroot /mnt reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Remove GPU temp module from polybar if nvidia not found
if [ "$nvidia_detected" = "no" ]; then
    arch-chroot /mnt sh -c "sed -i '/^modules-left =/ s/gpu-temp//' \"$USER_HOME/.config/polybar/config.ini\""
fi



# === Finish Installation === #

echo -e "${BOLD_BRIGHT_BLUE}Finishing up the installation...${NC}"

echo -e "${YELLOW}Restoring sudoers...${NC}"
# Restore the original sudoers file
arch-chroot /mnt mv /etc/sudoers.bak /etc/sudoers
arch-chroot /mnt rm /etc/sudoers.d/$USER_NAME
echo "%wheel ALL=(ALL:ALL) ALL" | arch-chroot /mnt tee -a /etc/sudoers > /dev/null

# Clean up
finishing-cleanup

# Disable the error trap
trap - ERR

echo -e "${GREEN}Installation complete. Please reboot into the new system.${NC}"
