=============
boot2kameleon
=============

What is boot2kameleon
=====================

boot2kameleon is a hybrid bootable ISO which starts a live Linux system based
on Debian. Its main purpose is to run Kameleon and to install appliance on
baremetal or virtual machine

The ISO is currently about 65 MB and is based on Debian jessie.

This project is based on debian2docker

How to build
============

Building boot2kameleon is quite simple with vagrant:

```
TARGET_VM="vm64" #or vm32

vagrant up $TARGET_VM
vagrant destroy -f $TARGET_VM
```

How to run
==========

1. Create a VM.
2. Add the ISO you've built as a virtual CD/DVD image.
3. Start the VM
4. Wait for the system to boot and start using debian2docker.


Linux & qemu/kvm example:
-------------------------

```
$ qemu-system-x86_64 -enable-kvm -cdrom boot2kameleon-VERSION-x86_64.iso -m 768
# wait for the system to boot and start using boot2kameleon
```
