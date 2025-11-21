# Partition Layout

This script has two different install modes, drive and partition, see below for details on each. 

## Drive layout

When selecting an entire drive to install on, the entire drive will be formatted. This will result int he loss of **ALL**
data on the drive.

The script will first create a `gpt` partition table on the drive. It will then create an EFI System Partition (ESP) 
with a FAT32 filesystem at 1 MiB going to 1GiB. The rest of the drive will then be formatted as a Primary partition
with btrfs installed. See [btrfs Subvolume Layout](btrfs-layout.md) for more info on btrfs.

GRUB and any other bootloader files should be installed in the EFI partition.

| **Start** | **End** | **Type** | **Filesystem** | **Description** |
| --------- | ------- | -------- | -------------- | --------------- |
| 1 MiB | 1 GiB | ESP | FAT32 | EFI (boot) partition | 
| 1 GiB | 100% | Primary | btrfs | Root partition | 

## Partition Layout

When selecting a single partition to install on, only that partition will be formatted, other partitions on the drive
will remain untouched. This will result in the loss of **ALL** data on the selected partition. 

**Important Note**: When installing on a single partition, no EFI partition will be installed. You must either already
have a bootloader configured or configure your own after the script has completed. If you don't know how to do this,
I recommend using the drive install type.

The script will format the selected partition as a Primary partition and install the btrfs filesystem on it. See
[btrfs Subvolume Layout](btrfs-layout.md) for more info on btrfs. This partition will be used as the root partition for
the installation.
