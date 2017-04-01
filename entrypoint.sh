#!/usr/bin/env bash
set -e

MOUNT_POINT=${MOUNT_POINT:-/mnt/nsafs_root}

mkdir -p $MOUNT_POINT
bundle exec ruby nsafs.rb $MOUNT_POINT -o "$MOUNT_OPTIONS" &
sleep 2
cd $MOUNT_POINT

exec "$@"
