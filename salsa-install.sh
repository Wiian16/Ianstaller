#!/bin/bash



# === Setup === #

# Set up logging
exec > >(tee arch_install.log)
exec 2>&1

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BRIGHT_BLUE='\033[1;34m' # Bright Blue
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










# === System Config Input === #


# Clear the screen for a clean start
clear

# Display welcome message
echo -e "${GREEN}Sam's Arch Linux Setup Assistant${NC}"
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

# Ask for the swap size with validation
while true; do
    read -p "Enter swap size in GiB (0 for no swap): " SWAP_SIZE
    if [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]] && [ "$SWAP_SIZE" -ge 0 ]; then
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
echo -e "${BLBRIGHT_BLUEUE}Root Partition:${NC} $ROOT_PARTITION"
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

# Partition the disk
echo "Partitioning the disk..."
parted /dev/"$DEVICE" --script mklabel gpt
parted /dev/"$DEVICE" --script mkpart ESP fat32 1MiB 513MiB
parted /dev/"$DEVICE" --script set 1 boot on
parted /dev/"$DEVICE" --script mkpart primary ext4 513MiB 100%


# Format the partitions
echo "Formatting the partitions..."
mkfs.fat -F32 "$EFI_PARTITION"
mkfs.ext4 "$ROOT_PARTITION"


# Mount the partitions
echo "Mounting the partitions..."
mount "$ROOT_PARTITION" /mnt
mkdir -p /mnt/boot/efi
mount "$EFI_PARTITION" /mnt/boot/efi


# Install essential packages
echo "Installing essential packages..."
pacstrap /mnt base linux linux-firmware grub efibootmgr zsh curl wget git nano


# Configure the system
echo "Configuring the system..."
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc
echo "$HOSTNAME" > /mnt/etc/hostname
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
arch-chroot /mnt locale-gen
echo "KEYMAP=us" > /mnt/etc/vconsole.conf
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /mnt/etc/hosts
echo root:"$USER_PASSWORD" | chpasswd --root /mnt
arch-chroot /mnt chsh -s /bin/zsh root


# Install and configure the bootloader
echo "Installing and configuring the bootloader..."
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg




# === Level 1 Installation

# Create a user account
echo "Creating user account..."
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh "$USER_NAME"
echo "$USER_NAME:$USER_PASSWORD" | chpasswd --root /mnt


# Set up sudo
echo "Setting up sudo..."
# Install sudo if it's not already installed
arch-chroot /mnt pacman -S --noconfirm sudo
# Uncomment to allow members of group wheel to execute any command
arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Set up a swap file
if [ "$SWAP_SIZE" -gt 0 ]; then
    echo "Setting up swap file..."
    arch-chroot /mnt fallocate -l "${SWAP_SIZE}G" /swapfile
    arch-chroot /mnt chmod 600 /swapfile
    arch-chroot /mnt mkswap /swapfile
    arch-chroot /mnt swapon /swapfile
    echo '/swapfile none swap defaults 0 0' >> /mnt/etc/fstab
fi

# Install and enable NetworkManager
echo "Installing and enabling NetworkManager..."
arch-chroot /mnt pacman -S --noconfirm networkmanager
arch-chroot /mnt systemctl enable NetworkManager


# Enable and start systemd-timesyncd for time synchronization
echo "Enabling and starting systemd-timesyncd for time synchronization..."
arch-chroot /mnt systemctl enable systemd-timesyncd.service
arch-chroot /mnt systemctl start systemd-timesyncd.service


# Install and setup UFW
echo "Installing and setting up UFW (Uncomplicated Firewall)..."
arch-chroot /mnt pacman -S --noconfirm ufw
# Enable basic firewall rules (deny incoming, allow outgoing)
arch-chroot /mnt ufw default deny incoming
arch-chroot /mnt ufw default allow outgoing
# Enable the firewall
arch-chroot /mnt ufw enable
# Enable UFW to start on boot
arch-chroot /mnt systemctl enable ufw






# === Level 2 Installation === #

# = Oh My Zsh = #

# Install Oh My Zsh for the root user without changing the shell or running Zsh
echo "Installing Oh My Zsh for the root user..."
arch-chroot /mnt sh -c "RUNZSH=no CHSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Oh My Zsh for the new user without changing the shell or running Zsh
echo "Installing Oh My Zsh for the new user..."
arch-chroot /mnt su - "$USER_NAME" -c "RUNZSH=no CHSH=no $(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Create the custom theme directory for the root user
arch-chroot /mnt mkdir -p /root/.oh-my-zsh/custom/themes

# Create the custom theme directory for the new user
arch-chroot /mnt mkdir -p /home/"$USER_NAME"/.oh-my-zsh/custom/themes

# Ensure the new user owns their home directory and contents
arch-chroot /mnt chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"


# = Yay = #

# Install Yay AUR Helper
echo "Installing Yay AUR Helper..."
arch-chroot /mnt pacman -S --needed --noconfirm git base-devel
arch-chroot /mnt su - "$USER_NAME" -c "git clone https://aur.archlinux.org/yay.git /tmp/yay"
arch-chroot /mnt su - "$USER_NAME" -c "cd /tmp/yay && makepkg -si --noconfirm"
arch-chroot /mnt rm -rf /tmp/yay



# = TLP = #

# Install TLP for power management
echo "Installing TLP for power management..."
arch-chroot /mnt pacman -S --noconfirm tlp tlp-rdw

# Enable TLP services
echo "Enabling TLP services..."
arch-chroot /mnt systemctl enable tlp.service
arch-chroot /mnt systemctl enable tlp-sleep.service







# === Level 3 Installation === #

# = Graphics Drivers = #

# Detect and install graphics drivers
echo "Detecting and installing graphics drivers..."

# Detect Intel and NVIDIA graphics
intel_detected=$(lspci | grep -E "VGA|3D" | grep -qi intel && echo "yes" || echo "no")
nvidia_detected=$(lspci | grep -E "VGA|3D" | grep -qi nvidia && echo "yes" || echo "no")

# Install Intel drivers only if Intel is detected and NVIDIA is not
if [ "$intel_detected" = "yes" ] && [ "$nvidia_detected" = "no" ]; then
    echo "Intel graphics detected. Installing Intel drivers..."
    arch-chroot /mnt pacman -S --noconfirm xf86-video-intel
fi

# Install AMD drivers if AMD graphics are detected
if lspci | grep -E "VGA|3D" | grep -qi amd; then
    echo "AMD graphics detected. Installing AMD drivers..."
    arch-chroot /mnt pacman -S --noconfirm xf86-video-amdgpu
fi

# Install NVIDIA drivers if NVIDIA graphics are detected (regardless of Intel)
if [ "$nvidia_detected" = "yes" ]; then
    echo "NVIDIA graphics detected. Installing NVIDIA drivers..."
    arch-chroot /mnt pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
fi



# = Micro Code = #

# Detect and install CPU microcode
echo "Detecting and installing CPU microcode..."

# Detect Intel CPU
if grep -qi intel /proc/cpuinfo; then
    echo "Intel CPU detected. Installing microcode..."
    arch-chroot /mnt pacman -S --noconfirm intel-ucode
fi

# Detect AMD CPU
if grep -qi amd /proc/cpuinfo; then
    echo "AMD CPU detected. Installing microcode..."
    arch-chroot /mnt pacman -S --noconfirm amd-ucode
fi

# Regenerate initramfs to include microcode updates
echo "Regenerating initramfs..."
arch-chroot /mnt mkinitcpio -P



# = Audio = #

# Install audio packages
echo "Installing audio packages..."
arch-chroot /mnt pacman -S --noconfirm pulseaudio pulseaudio-alsa alsa-utils pavucontrol

# Install Bluetooth packages
echo "Installing Bluetooth packages..."
arch-chroot /mnt pacman -S --noconfirm bluez bluez-utils



# = Bluetooth = #

# Enable the Bluetooth service
echo "Enabling Bluetooth service..."
arch-chroot /mnt systemctl enable bluetooth.service

# Install and enable additional Bluetooth tools and services
arch-chroot /mnt pacman -S --noconfirm pulseaudio-bluetooth blueman










# === Level 4 Installation === #

# Define an array of packages to install
PACKAGES=(
    # Xorg
    xorg-server xorg-xinit xorg-apps xorg-xrandr xorg-xsetroot xorg-xbacklight xsettingsd lxappearance
    # Window manager and tools
    bspwm sxhkd
    # Display manager
    sddm
    # Terminal emulator, file manager, and utilities
    thunar alacritty neofetch
    # Polybar, picom, dunst, and conky
    polybar picom dunst conky
    # Fonts
    ttf-dejavu ttf-liberation noto-fonts ttf-jetbrains-mono-nerd ttf-jetbrains-mono

    # Other packages for config files
    rofi feh copyq mpc alsa-utils pulseaudio playerctl
    discord neovim ranger htop
)

AUR_PACKAGES=(
    google-chrome ksuperkey xfce-polkit
)


# Install all packages in the array
echo "Installing packages..."
arch-chroot /mnt pacman -S --noconfirm "${PACKAGES[@]}"

# Install all AUR packages in the array
echo "Installing AUR packages..."
arch-chroot /mnt su - "$USER_NAME" -c "/usr/bin/yay -S --noconfirm ${AUR_PACKAGES[@]}"

# Enable SDDM
echo "Enabling SDDM..."
arch-chroot /mnt systemctl enable sddm.service

# Clone the user's dotfiles repository
echo "Cloning the user's dotfiles repository..."
arch-chroot /mnt su - "$USER_NAME" -c "git clone https://github.com/SamsterJam/DotFiles.git /home/$USER_NAME/.dotfiles"

# Apply the dotfiles
echo "Applying the dotfiles..."
arch-chroot /mnt su - "$USER_NAME" -c "mkdir -p /home/$USER_NAME/.config"
arch-chroot /mnt su - "$USER_NAME" -c "cp -r /home/$USER_NAME/.dotfiles/* /home/$USER_NAME/.config/."

# Ensure the new user owns their home directory and contents
arch-chroot /mnt chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"

# Clean up
echo "Cleaning up..."
arch-chroot /mnt pacman -Scc --noconfirm

# Finish up
echo "Finishing up the desktop environment installation..."
echo -e "${GREEN}Desktop environment installation complete. Please reboot into the new system.${NC}"




# === Finish Installation === #

echo "Finishing up the installation..."
fuser -km /mnt
sleep 2
umount -R /mnt
echo -e "${GREEN}Installation complete. Please reboot into the new system.${NC}"