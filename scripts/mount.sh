#!/usr/bin/env bash

set -euo pipefail

EXPECTED_ARGUMENTS=1

if [ "$#" -ne "$EXPECTED_ARGUMENTS" ]; then
  echo "Usage: $0 <device>"
  exit 1
fi

DEVICE=$1

mount -o compress=zstd,subvol=@ $DEVICE /mnt
mkdir -p /mnt/home
mount -o compress=zstd,subvol=@home $DEVICE /mnt/home
mkdir -p /mnt/var/log
mount -o compress=zstd,subvol=@var_log $DEVICE /mnt/var/log
mkdir -p /mnt/.snapshots
mount -o compress=zstd,subvol=@snapshots $DEVICE /mnt/.snapshots
