# Scripts

This directory holds some scripts that can be useful for debugging or development. Below is a short description of each
script in the directory.

## `mount.sh`

Mounts the given device with the correct subvolume layout installed by the install script under /mnt

### Usage

`./mount.sh <device>`

## `build_official_repo.sh`

Reads all official packages from `packages/` and builds a local pacman repo for development. This is only recommended
for development use to speed up package downloads and avoid getting throttled by mirrors. This should be run on a
host separate from the installer.

The script will create a cache directory at `/var/cache/ianstaller/` and a local repo at `repo-official`.

### Usage

**Run the following commands from the project root:**

Download and create the local repo: 

```bash
scripts/build_official_repo.sh
```

Create a server for the local repo: 

```bash
python scripts/serve-repos.py
```

**Run the following command from the host running the installer:**

```bash
./setup_installer_repos.sh <local-repo-ip-address>
```

Then run the installer as normal, all official packages should be fetched from the host with the local repo. 

## `serve-repos.py`

Creates an http server for the local pacman repo. See `build_official_repo.sh` for usage info.

## `setup_installer_repos.sh`

Modifies `/etc/pacman.conf` to use the local network pacman cache before mirrors. See `build_official_repo.sh` for 
usage info.
