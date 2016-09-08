.. _`use cases`:

---------
Use Cases
---------

Here it is described different use cases for Kameleon. It should give you a better
idea, through examples, of how Kameleon is useful for.

Distribute an environnement to your co-workers/students/friends/...
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Whit Kameleon you can easily export your environment in any format. The
export section of the recipe is made for this. For example, if you would like
to export your image in VDI format to use VirtualBox you just have to set
the export format wirh using the ``appliance_formats`` option either in
your recipe or whit the CLI:

.. code-block:: yaml

  global:
    appliance_formats: vdi

And that's it! Whatever the backend you choose kameleon default recipes are
able to export it in any supported format:
Allowed formats are: tar.gz, tar.bz2, tar.xz, tar.lzo, qcow, qcow2, qed,
vdi, raw, vmdk


Make a Linux virtual machine with graphical support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
You can directly use the templates that provide a desktop. However, here is an
example of adding desktop capability to the ``debian8`` template. First create
a new recipe from this template:

.. code-block:: bash

     kameleon new debian8-desktop default/from_image/debian8

Then edit the recipe file ``debian8-desktop.yaml`` and add ``gnome-core`` and ``xorg``
packages to the install list:

.. code-block:: yaml

    setup:
        # Install
        - software_install:
          - packages: >
              debian-keyring ntp zip unzip rsync sudo less vim bash-completion
              gnome-core xorg

These packages take some extra space, so add some space on the disk. 4G should
be enough:

.. code-block:: yaml

    global:
        ...
        image_size: 10G

Build your recipe:

.. code-block:: bash

    kameleon build debian8-desktop

When the build has finished, you can try you image with Qemu:

.. code-block:: bash

    qemu-system-x86_64 -m 1024 --enable-kvm \
        builds/debian8-desktop/debian8-desktop.qcow2

Alternatively, you could use ``virt-manager`` that provide a good GUI to manage
your virtual machines.

.. note::
    If you want a better integration between the host and the guest like
    copy/paste use ``spice`` (http://www.linux-kvm.org/page/SPICE)


Create a fully reproducible experimental environement
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To be sure that your image can be fully reproduce, you should use the
:ref:`persistent_cache` feature. It creates a cache compress tarball that
contains everything that was downloaded during the build and allows to
recreate your image from it directly using:

.. code-block:: bash

    kameleon build --from-cache my_recipe-cache.tar.gz

You can even use the ``--offline`` mode to be sure that your recipe is
built without accessing to the web.

To find a compete example refer to this repository that was made for a
reproducible set of experiments:
https://github.com/oar-team/batsim-env-recipes

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
