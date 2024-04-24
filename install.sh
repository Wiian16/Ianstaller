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
echo -e "${GREEN}Sam's Simplified Arch Linux Installation Script${NC}"
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




# === Installation == #



# Function to partition the disk (dry run)
partition_disk() {
    echo "Partitioning the disk (dry run)..."
    echo "Creating EFI partition on $EFI_PARTITION"
    echo "Creating root partition on $ROOT_PARTITION"
    # Add commands for partitioning here, using tools like parted or fdisk
}

# Function to format the partitions (dry run)
format_partitions() {
    echo "Formatting the partitions (dry run)..."
    echo "Formatting $EFI_PARTITION as FAT32 for the EFI system partition"
    echo "Formatting $ROOT_PARTITION as ext4 for the root file system"
    # Add commands for formatting here, using mkfs.fat and mkfs.ext4
}

# Function to mount the partitions (dry run)
mount_partitions() {
    echo "Mounting the partitions (dry run)..."
    echo "Mounting $ROOT_PARTITION to /mnt"
    echo "Mounting $EFI_PARTITION to /mnt/boot"
    # Add mount commands here
}

# Function to install essential packages (dry run)
install_packages() {
    echo "Installing essential packages (dry run)..."
    echo "Pacstrap base, linux, linux-firmware into /mnt"
    # Add pacstrap command here
}

# Function to configure the system (dry run)
configure_system() {
    echo "Configuring the system (dry run)..."
    echo "Generating fstab"
    echo "Setting timezone to $TIMEZONE"
    echo "Setting hostname to $HOSTNAME"
    echo "Setting locale to en_US.UTF-8"
    echo "Setting vconsole keyboard layout"
    echo "Setting up network configuration"
    echo "Setting root password"
    # Add system configuration commands here
}

# Function to install and configure the bootloader (dry run)
install_bootloader() {
    echo "Installing and configuring the bootloader (dry run)..."
    # Add bootloader installation commands here
}

# Function to finish up the installation (dry run)
finish_installation() {
    echo "Finishing up the installation (dry run)..."
    echo "Unmounting partitions"
    echo "Rebooting the system"
    # Add unmount and reboot commands here
}



# Start the installation process (dry run)
partition_disk
format_partitions
mount_partitions
install_packages
configure_system
install_bootloader
finish_installation

echo -e "${GREEN}Dry run complete. If this were a real installation, the system would now be installed.${NC}"