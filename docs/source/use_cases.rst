.. _`use cases`:

---------
Use Cases
---------

Here it is described different use cases for Kameleon. It should give you a better
idea, through examples, of how Kameleon is useful for.

Distribute an environnement to your co-workers/students/friends/...
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Whit Kameleon you can easily export your environnement in any format. The
export section of the recipe is made for this. For example, if you would like
to export your image in vdi format to use VirtualBox you just have to uncomment
the right line. Like in the debian7 template::

    #== Export the generated appliance in the format of your choice
    export:
      - save_appliance_from_nbd:
        - mountdir: $$rootfs
        - filename: "$${kameleon_recipe_name}"
        - save_as_qcow2
        # - save_as_qed
        # - save_as_tgz
        # - save_as_raw
        # - save_as_vmdk
        - save_as_vdi

Make a Linux virtual machine with graphical support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
You can directly use the templates that provide a desktop. However, here is an
example of adding desktop capability to the ``debian8`` template. First create
a new recipe from this template::

     kameleon new debian8-desktop -t debian8

Then edit the recipe file ``debian8-desktop.yaml`` and add ``gnome-core`` and ``xorg``
packages to the install list::

    setup:
        # Install
        - software_install:
          - packages: >
              debian-keyring ntp zip unzip rsync sudo less vim bash-completion
              gnome-core xorg

These packages take some extra space, so add some space on the disk. 4G should
be enough::

    bootstrap:
        ...
        - create_disk_nbd:
            - image_size: 4G

Build your recipe::

    sudo kameleon build debian8-desktop

When the build has finished, you can try you image with Qemu::

    sudo qemu-system-x86_64 -m 1024 --enable-kvm -vga std \
        builds/debian8-desktop/debian8-desktop.qcow2

Alternatively, you could use ``virt-manager`` that provide a good GUI to manage
your virtual machines.

.. note::
    If you want a better integration between the host and the guest like
    copy/paste use ``spice`` (http://www.linux-kvm.org/page/SPICE)


Create a fully reproducible experimental environement
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
You should use the :ref:`persistent_cache` feature.

.. todo::
    Give a complete use case.

Create a persistent live USB key
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
A dirty but reliable method to do this is to cat the entire raw disk on the USB
key. First be sure that the disk size is equal or smaller then your
Then, export you image in raw format (this is the disk content bit by bit) and
dump it to your USB key. Once your image is built, if your USB key is the
``/dev/sdb`` device, be sure that it is not mounted and just do this::

    cat my_image.raw > /dev/my_key

.. warning::
    This is a dangerous operation, you usb key will erase without
    warning! Be sure that you pick the right device (use lsblk): it should be
    ``/dev/sdX`` where X is a letter. Do NOT use the ``dev/sdXY``. unmount it
    and use the root device instead.
