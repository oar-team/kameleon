#!/bin/bash
set -e

WORKDIR_ISO="$WORKDIR/iso/"

echo "---> clean up the root directory"
(
    cd $ROOTFS_DIR && mv boot/vmlinuz* $WORKDIR/vmlinuz
    chroot $ROOTFS_DIR apt-get clean
    rm -rf boot
)
echo "---> copying includes.chroot"
cp -Rfp $INCLUDESCHROOTDIR/* $ROOTFS_DIR

cp -Rfp $HOOKSDIR $ROOTFS_DIR

echo "---> running hooks"
(
    cd $ROOTFS_DIR/hooks
    for i in *.chroot; do
        echo ' ---> running hook: ' $i
        chroot $ROOTFS_DIR bash /hooks/$i
    done
    rm -rf $ROOTFS_DIR/hooks
)

echo "---> preparing the rootfs"
(   cd $ROOTFS_DIR
    find . | cpio --quiet -H newc -o | xz -8 > $WORKDIR/initramfs-data.xz
    cd $WORKDIR
    mkdir -p RAMFS
    cd RAMFS
    mv $WORKDIR/initramfs-data.xz rootfs.xz
    find . | cpio --quiet -H newc -o | gzip -1 > $WORKDIR/ramdisk-data.gz
    cat $WORKDIR/init.gz $WORKDIR/ramdisk-data.gz > $WORKDIR/ramdisk-final.gz
    rm -rf $ROOTFS_DIR
)

echo "---> building the iso"
mkdir -p $WORKDIR/iso/boot/isolinux
mkdir -p $WORKDIR/iso/live/
cp /usr/lib/syslinux/isolinux.bin $WORKDIR/iso/boot/isolinux/
cp $WORKDIR/vmlinuz $WORKDIR/iso/live/
cp $WORKDIR/ramdisk-final.gz $WORKDIR/iso/live/initrd.img
cp -Rfp $INCLUDESBINARYDIR/* $WORKDIR/iso/

xorriso -as mkisofs \
    -l -J -R -V debian2docker -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
    -isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin \
    -o $1 $WORKDIR/iso

rm -rf $WORKDIR/iso
rm -rf $WORKDIR/RAMFS
