# JamInstaller

JamInstaller is a custom Arch Linux installer script designed to automate the installation and configuration of a polished Arch Linux system. This script takes minimal input from the user and sets up a complete system with essential packages, configurations, and a beautiful desktop environment (with my own custom theme script)!

## Features

- Automated disk partitioning and formatting
- Installation of essential packages and configurations
- User account creation and configuration
- Installation of graphics drivers, audio packages, and Bluetooth support
- Setup of a custom desktop environment with bspwm, polybar, and more
- Installation of additional utilities and applications
- Configuration of Oh My Zsh and custom themes
- Power management with TLP
- Firewall setup with UFW
- Automated handling of dotfiles and themes

## Prerequisites

- A bootable Arch Linux ISO USB
- An internet connection
- **UEFI firmware (this script does not support BIOS installations)**

## Usage

1. **Boot from the Arch Linux ISO USB:**
   - Insert the USB into your computer and boot from it.

2. **Download the JamInstaller script:**
   ```sh
   curl -O -L samsterjam.com/jam-installer.sh
   ```

3. **Make the script executable:**
   ```sh
   chmod +x jam-installer.sh
   ```

4. **Run the script:**
   ```sh
   ./jam-installer.sh
   ```

5. **Follow the on-screen prompts:**
   - Enter the hostname
   - Enter the timezone (e.g., `America/New_York`)
   - Enter the new username
   - Enter and confirm the password for the new user (this will also be the root password)
   - Select the device to install on (e.g., `sda`)
   - Enter the swap size in GiB (0 for no swap)
   - Confirm the installation summary and proceed

## Installation Summary

The script will perform the following steps:

1. **System Configuration Input:**
   - Collects hostname, timezone, username, password, device, and swap size from the user.

2. **Level 0 Installation:**
   - Modifies `pacman.conf` for parallel downloads and color.
   - Partitions and formats the disk.
   - Mounts the partitions.
   - Installs essential packages.
   - Configures the system (timezone, locale, hostname, etc.).
   - Installs and configures the bootloader.

3. **Level 1 Installation:**
   - Creates a user account.
   - Sets up sudo.
   - Configures a swap file (if specified).
   - Installs and enables NetworkManager.
   - Enables systemd-timesyncd for time synchronization.
   - Installs and sets up UFW (Uncomplicated Firewall).

4. **Level 2 Installation:**
   - Installs Oh My Zsh for the root and new user.
   - Installs Yay AUR Helper.
   - Installs TLP for power management.

5. **Level 3 Installation:**
   - Detects and installs graphics drivers.
   - Installs CPU microcode.
   - Installs audio packages and Bluetooth support.
   - Sets up udiskie for automounting USB drives.

6. **Level 4 Installation:**
   - Temporarily makes sudo passwordless for the new user.
   - Installs a list of packages and AUR packages.
   - Enables SDDM.
   - Clones the user's dotfiles repository.
   - Applies dotfiles and custom themes.
   - Restores sudoers configuration.

7. **Finish Installation:**
   - Cleans up and finalizes the installation.

## Post-Installation

After the script completes, reboot your system into the new Arch Linux installation. You should have a fully configured and polished Arch Linux system ready to use.

## Disclaimer

JamInstaller is a custom Arch Linux installer script created by a single developer primarily for personal use and to share with friends who want to try Arch Linux. This script is not intended to be a distributed operating system and comes with several limitations and caveats:

1. **Limited Testing and Support:**
   - This script has only been tested on the developer's personal computers, which have Intel CPUs and Nvidia graphics cards.
   - It has also been tested in virtual machines, where some configurations had to be adjusted (e.g., using xrender instead of glx in picom).
   - The script includes specific configurations for Nvidia graphics cards, but lacks similar support for other hardware.

2. **Hardware Compatibility:**
   - The script may not work perfectly on all systems out of the box. For example, the polybar configuration assumes the presence of certain hardware sensors and Nvidia-specific modules.
   - Users with different hardware may need to manually adjust configurations to achieve optimal performance.

3. **Configuration Specificity:**
   - The script includes many configurations tailored to the developer's personal setup. These configurations may not be suitable for all users.
   - Conditional configurations and broader compatibility have not been a focus of this project. Users may need to have some knowledge of Arch Linux and its configuration to make necessary adjustments.

4. **No Warranty:**
   - This script is provided as-is without any warranty. The developer is not responsible for any issues that may arise from using this script.
   - Users are advised to back up their data before running the script and to use it at their own risk.

5. **Not a General-Purpose Installer:**
   - If you are looking for a more robust and general-purpose Arch Linux installer, consider using [Archcraft](https://archcraft.io/), which is designed to work for newcomers with different systems and provides a more polished out-of-the-box experience.

6. **Community and Contributions:**
   - While contributions and suggestions are welcome, users should be aware that this project is maintained by a single developer and may not receive frequent updates or extensive support.

By using JamInstaller, you acknowledge that you understand these limitations and agree to use the script at your own risk. The primary goal of this project is to share a specific Arch Linux setup with friends and to provide a starting point for those who are comfortable making their own adjustments.


## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

A significant portion of the configuration files used in this project are based on the work of the creator of Archcraft. Over the years, I have customized and built upon these configurations to create my own setup. You can find more about Archcraft and its creator here:

- [Archcraft Website](https://archcraft.io/)
- [adi1090x's Github](https://github.com/adi1090x)

---

**Note:** This script is provided as-is without any warranty. Use it at your own risk. Always back up your data before running any installation script.