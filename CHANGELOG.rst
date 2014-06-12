Kameleon CHANGELOG
==================

version 2.1.0
-------------

Released on May 12th 2014

- [core] Fixed psych yaml parsing (#1)
- [core] Changed option ``--no-no-color`` to ``--color``
- [core] Saved the contexts state files in their WORKDIR (#3)
- [core] Set context in/out/local cmd to /bin/bash by default (#5)
- [core] Made global section non mandatory
- [core] Made writing embedded step in recipe possible (#12)
- [core] Improved the readability of logs and the progress bar
- [core] Moved aliases and checkpoints folders to steps
- [core] Removed the ``recipes`` folder and the ``workspace`` (#2)
- [core] Make a safe copy with ``kameleon new`` command
- [core] Added a simple extend recipe feature (#11)
- [core] Introduced the keyword "@base" in the extended recipes (#11)
- [core] Don't log identifier of microstep during build process
- [core] Added ``kameleon import`` command (#11)
- [core] Added ``--clean`` option to ``kameleon build`` command
- [core] Added the lazy context initialization (#10)
- [core] Set the variable ``KAMELEON_WORKDIR`` for all contexts
- [core] Used ``KAMELEON_WORKDIR`` when working with PIPE
- [core] Added persistent cache feature to Kameleon, So far it is caching just packages comming from the network using Polipo
- [template] Added new templates :

  - archlinux
  - archlinux-desktop
  - debian-testing
  - debian7
  - debian7-desktop
  - debian7-oar-dev
  - fedora-rawhide
  - fedora20
  - fedora20-desktop
  - ubuntu-12.04
  - ubuntu-12.04-desktop
  - ubuntu-14.04
  - ubuntu-14.04-desktop
  - vagrant-debian7
- [template] Installed the extlinux bootloader depending on distributions
- [template] New way to bootstrap fedora using Liveos image
- [template] Installed linux kernel and extlinux bootloader from bootstrap section
- [template] Used parted instead of sfdisk
- [template] Added save_as_qed step
- [template] Removed insecure ssh key before any export
- [template] Added shell auto-completion for bash, zsh and fish shell
- [template] Default user group is sudo
- [template] Added a new qemu/kvm template with full-snapshot support
- [template] Ability to add user in multiple groups (with usermod -G)
- [template] Improved I/O performance with qemu/kvm
- [template] Removed force-unsafe-io for dpkg to avoid corrupted filesystem
- [template] Used qemu by default instead of chroot
- [template] Added option to disable debootstrap cache
- [template] Refactor qcow2 backing file checkpoints
- [template] Make QEMU checkpoint more robust and avoid disk corruption
- [template] Major revision of steps to make it easier to use in different templates
- [template] Rename steps for more semantic consistency
- [template] Making the 'save_appliance' step not dependent on the state of the machine
- [template] Enabled cache for arch_bootstrap
- [template] Added openssh in arch-bootstrap and enabled sshd.service/dhcp.service
- [template] Added user 'nobody' to allow sshd  to run in the archlinux virtual machine
- [template] Enabled checkpoints (backing-file) only in the "setup" stage
- [template] Fixed .ssh and authorized_keys permissions
- [template] Avoid crash of in_context when we send a shutdown command to the virtual machine
- [template] Exclude special files with rsync (proc/dev...) when copying rootfs to the disk
- [template] Force stop qemu if still running
- [template] Make debian-chroot depreciated
- [template] Refactor archlinux template to use it with qemu/kvm
- [template] Improved the LiveOS fedora bootstrap step to get the system running with qemu/kvm
- [template] Refactor fedora20/debian8 templates to use them with qemu/kvm
- [template] Set timezone to UTC by default
- [template] Used ProxyCommand to improve the debian7-g5k recipe
- [aliases] Updated write_file and append_file aliases to support double quotes
- [aliases] Defined new aliases for unmounting devices
- [docs] More documentation


version 2.0.0
=============

Released on February 17th 2014

Initial public release of kameleon 2
