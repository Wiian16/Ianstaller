# Ianstaller v2 Roadmap

Goal: Rebuild this Arch Linux install script into a modular, maintainable, and documented system that safely installs 
Arch with Btrfs, bspwm, and my dotfiles while supporting development and gaming use cases.

## Roadmap

- [ ] Foundation and Infrastructure 
- [ ] Core Installation Pipeline 
- [ ] System Configuration 
- [ ] User Environment (Desktop and Dotfiles) 
- [ ] Developer and Gaming modules 
- [ ] Safety, Maintainability, and Documentation  

## 1. Foundation and Infrastructure

Set up the installer's structure, shared utilities, and configuration handling.

- [ ] Create project structure
    - `ianstaller/` root with `/modules`, `/docs`
- [ ] Write `config.sh`
    - Define username, hostname, drive, filesystem options, package groups
    - Include per-profile configs (desktop / dev / gaming)
- [ ] Write `helpers.sh`
    - Logging functions (`info()`, `warn()` `error()`)
    - Prompt utilities (`confirm()`, `pause()`)
    - Execution wrappers with error handling
- [ ] Write main runner (`install.sh`)
    - Parse main arguments (`--dry-run`, `--skil <module>`)
    - Source `config.sh` and each module sequentially
    - Log to `ianstaller.log`
- [ ] Add dry-run mode
    - Replace destructive commands with `echo` when `DRY_RUN=true`

## 2. Core Installation Pipeline

Automate the reproducible base Arch installation using Btrfs

- [ ] Module 00: Partitioning
    - Detect disks and confirm before formatting 
    - Create GPT with EFI + Btrfs partitions
    - Optionally support USB installs
- [ ] Module 01: Btrfs setup
    - Format partition with `mkfs.btrfs`
    - Create subvolumes: `@`, `@home`, `@log`, `@snapshots`, etc.
    - Document layout in `docs/btrfs-layout.md`
- [ ] Module 02: Mount and base install
    - Mount subvolumes correctly under `/mnt`
    - Install base packages with `pacstrap`
    - Generate `fstab` and copy `config.sh` into chroot
- [ ] Module 03: Chroot configuration
    - Set timezone, locale, hostname
    - Configure initramfs for Btrfs
    - Install bootloader (GRUB)
    - Set up networking and create user

## 3. System Configuration

Make the base system functional post-install (core services, updates, defaults)

- [ ] Enable services: `NetworkManager`, `bluetooth`, `systemd-timesyncd`
- [ ] Configure sudoers (`wheel` group)
- [ ] Configure shell (oh my zsh)
- [ ] Add basic system aliases and scripts
- [ ] Install essential command-line tools (from `PACKAGES_CORE`)
- [ ] Setup microcode and drivers (AMD/Intel/NVIDIA)
- [ ] Optionally install Flatpak and basic repos
- [ ] Pacman hooks and systemd timers
    - Pre/post snapshots for pacman, pacman/yay cache timers, reflector timers, etc.
- [ ] Pacman parallel downloads. 

## 4. User Environment (Desktop and Dotfiles)

Build the bspwm-based desktop environment and integrate dotfiles

- [ ] Module 04: Desktop
    - Install Xorg, bspwm, sxhkd, polybar, picom, dunst, alacritty, etc. 
    - Configure display manager (`sddm`)
    - Set default session for user
- [ ] Module 05: Dotfiles
    - Install `git` and `chezmoi` or `yadm`
    - Pull dotfiles from repo
    - Apply templates for machine-specific configs (e.g. desktop vs USB)
    - Set default shell and terminal
- [ ] Validate post-install login to desktop

## 5. Developer and Gaming Modules

Install tools for workflows -- development and gaming

- [ ] Module 06: Developer tools
    - Install compilers, SDKs and editors (Rust, Go, Python, Neovim, etc.)
    - Configure Git, SSH keys, and global `.gitconfig`
    - Set environment variables and aliases
    - Setup virtualisation (virt-manager and UFW rules)
- [ ] Module 07: Gaming
    - Detect GPU and install appropriate driver stack
    - Install Steam, Lutris(?), MangoHud, Gamemode, and 32-bit libraries
    - Apply steam tweaks for performance (e.g. `sysctl`, I/O schedulers)
    - Install Wine/Proton-GE support
- [ ] Optional: Add modules for creative or media tools

## 6. Safety, Maintainability, and Documentation

Add the features that make the system safe to use long-term and easy to maintain.

- [ ] Add dry-run mode (expanded) 
    - Implement global toggle in `install.sh`
    - Log all commands and skip execution safely
- [ ] Add confirmation for destructive actions
    - Require double confirmation for partitioning or formatting
    - Add `--no-confirm` option for unattended installs
- [ ] Add rollback/snapshot support
    - Automatically create Btrfs snapshot pre/post install
- [ ] Add module skipping
    - Allow `--skip desktop` or `--skip gaming` for minimal installs
- [ ] Add logging and failure recovery
    - Centralize all logs in `ianstaller.sh`
    - Add `trap` for cleanup on failure
- [ ] Write documentation
    - `README.md` overview and usage
    - `docs/partitioning.md`, `btrfs-layout.md`, `software.md`, etc.
    - Troubleshooting guide
- [ ] Add optional extra features
    - Deej, etc.
