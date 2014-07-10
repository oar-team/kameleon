#!/bin/bash
set -e

export CURRENT_DIR=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
export WORKDIR=$(mktemp -d)
export DEBOOTSTRAP_DIR=/var/cache/debootstrap
export ROOTFS_DIR=$WORKDIR/rootfs

export INCLUDESCHROOTDIR=$CURRENT_DIR/../includes.chroot
export INCLUDESBINARYDIR=$CURRENT_DIR/../includes.binary
export HOOKSDIR=$CURRENT_DIR/../hooks

export EXPORT_DIR=${1:-$PWD}

## make ramedisk
bash $CURRENT_DIR/build_ramdisk.sh $WORKDIR $WORKDIR/init.gz $CURRENT_DIR/init

## Debootstrap
mkdir -p $DEBOOTSTRAP_DIR
sudo bash $CURRENT_DIR/debootstrap.sh $DEBOOTSTRAP_DIR

## Generate iso
rsync -aAX --exclude '/.kameleon_timestamp' $DEBOOTSTRAP_DIR/* $ROOTFS_DIR
bash $CURRENT_DIR/build_iso.sh $EXPORT_DIR/debian-jessie-$(uname -m)-insecure.iso
