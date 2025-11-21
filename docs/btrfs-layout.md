# btrfs Subvolume Layout

The btrfs subvolumes layout follows the suggested layout for snapper on the 
[Arch Wiki](https://wiki.archlinux.org/title/Snapper#Suggested_filesystem_layout). 

**Filesystem Layout**

| **Subvolume** | **Mount Point** | 
| --- | --- | 
| @ | `/` |
| @home | `/home` | 
| @var_log | `/var/log` | 
| @snapshots | `/.snapshots` | 

As described in the wiki article, this layout is *not* inteded to be used with `snapper rollback`, but solves some
problems with restoring the root directory from a previous snapshot. 

Should the system become unbootable, it can be recovered from a live ISO without rolling back the home or any other
subvolumes. See 
[Restoring / to its previous snapshot](https://wiki.archlinux.org/title/Snapper#Restoring_/_to_its_previous_snapshot)
on the Arch Wiki for more information.

To restore other subvolumes to previous snapshots, see the 
[page on the Arch Wiki](https://wiki.archlinux.org/title/Snapper#Restore_snapshot) for more information.
