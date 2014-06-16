---------------
Getting Started
---------------

Installation
~~~~~~~~~~~~

To install Kameleon have a look at the :doc:`installation` section.

Create a new recipe from template
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

First thing to know is that Kameleon is an automation tool for bash. It brings
the ease of error handling, retry, checkpointing, easy debugging and cleaning
to your scripts to help you build your software appliance.

The template system built-in allows you quickly build a system and to understand the
Kameleon basics. Let see the template list::

    kameleon templates

It shows the templates names and descriptions directly from the templates files shipped
with  Kameleon::

    The following templates are available in /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates:
    NAME                 | DESCRIPTION
    ---------------------|-----------------------------------------------------------
    archlinux            | Build an Archlinux base system system.
    archlinux-desktop    | Archlinux GNOME Desktop edition.
    debian-testing       | Debian Testing base system
    debian7              | Debian 7 (Wheezy) base system
    debian7-desktop      | Debian 7 (Wheezy) GNOME Desktop edition.
    debian7-kameleon     | Debian 7 appliance with kameleon.
    debian7-oar-dev      | Debian 7 dev appliance with OAR-2.5 (node/server/frontend).
    docker-debian7       | Build a debian image for docker with docker
    fedora-rawhide       | Fedora Rawhide base system
    fedora20             | Fedora 20 base system
    fedora20-desktop     | Fedora 20 GNOME Desktop edition
    old-debian7          | [deprecated] Build a debian wheezy appliance using chroot...
    ubuntu-12.04         | Ubuntu 12.04 LTS (Precise Pangolin) base system.
    ubuntu-12.04-desktop | Ubuntu 12.04 LTS (Precise Pangolin) Desktop edition.
    ubuntu-14.04         | Ubuntu 14.04 LTS (Trusty Tahr) base system.
    ubuntu-14.04-desktop | Ubuntu 14.04 LTS (Trusty Tahr) Desktop edition.
    vagrant-debian7      | A standard Debian 7 vagrant base box

Let's pick one of these. The ``debian7`` is a good example. Now you
will create a new recipe from this template.  Let's name it ``my_debian``::

    kameleon new my_debian debian7

Kameleon make a direct copy of the YAML template recipe file and all
the other required files like steps or aliases ones. You can see that in the
``new`` command output::

    [kameleon]: Cloning template 'debian7'...
    [kameleon]: create /root/debian7.yaml
    [kameleon]: create /root/steps/aliases/defaults.yaml
    [kameleon]: create /root/steps/checkpoints/qemu.yaml
    [kameleon]: create /root/steps/export/save_appliance.yaml
    [kameleon]: create /root/steps/setup/debian/configure_apt.yaml
    [kameleon]: create /root/steps/setup/debian/upgrade_system.yaml
    [kameleon]: create /root/steps/setup/debian/install_software.yaml
    [kameleon]: create /root/steps/setup/debian/configure_kernel.yaml
    [kameleon]: create /root/steps/setup/debian/configure_system.yaml
    [kameleon]: create /root/steps/setup/debian/configure_keyboard.yaml
    [kameleon]: create /root/steps/setup/debian/configure_network.yaml
    [kameleon]: create /root/steps/setup/create_group.yaml
    [kameleon]: create /root/steps/setup/create_user.yaml
    [kameleon]: create /root/steps/bootstrap/debian/debootstrap.yaml
    [kameleon]: create /root/steps/bootstrap/initialize_disk_qemu.yaml
    [kameleon]: create /root/steps/bootstrap/prepare_qemu.yaml
    [kameleon]: create /root/steps/bootstrap/install_bootloader.yaml
    [kameleon]: create /root/steps/bootstrap/start_qemu.yaml
    [kameleon]: Creating extended recipe from template 'debian7'...
    [kameleon]: create /root/my_debian.yaml
    [kameleon]: done

You can check that you got all the files in your workspace for example with the
UNIX ``tree`` command::

    tree
    .
    `-- debian7.yaml
    `-- my_debian.yaml
    `-- steps
        |-- aliases
        |   `-- defaults.yaml
        |-- bootstrap
        |   |-- debian
        |   |   `-- debootstrap.yaml
        |   |-- initialize_disk_qemu.yaml
        |   |-- install_bootloader.yaml
        |   |-- prepare_qemu.yaml
        |   `-- start_qemu.yaml
        |-- checkpoints
        |   `-- qemu.yaml
        |-- export
        |   `-- save_appliance.yaml
        `-- setup
            |-- create_group.yaml
            |-- create_user.yaml
            `-- debian
                |-- configure_apt.yaml
                |-- configure_kernel.yaml
                |-- configure_keyboard.yaml
                |-- configure_network.yaml
                |-- configure_system.yaml
                |-- install_software.yaml
                `-- upgrade_system.yaml


    8 directories, 19 files

To understand this hierarchy please refer to the :doc:`recipe` documentation.

Build my new recipe
~~~~~~~~~~~~~~~~~~~

.. note::
    Be sure to be `root` to run the following steps. It is needed for loading
    modules, chrooting,...

There is no magic in Kameleon, everything is written in YAML:
from your system bootstrap to its export. It empowers you to customize anything
you want at anytime during the appliance build. But before changing anything
just build the template to see how it works::

     kameleon build my_debian

Oups! Maybe you get an error like this::

    ...
    [kameleon]: debootstrap is missing from out_context
    [kameleon]: Press [c] to continue with execution
    [kameleon]: Press [a] to abort execution
    [kameleon]: Press [l] to switch to local_context shell
    [kameleon]: Press [o] to switch to out_context shell
    [kameleon]: Press [i] to switch to in_context shell
    [kameleon]: answer ? [i/o/l/a/c]:

This is the interactive prompt of Kameleon.

It is a powerful tool that offers you the possibility to fix a problem if
something goes wrong during the build process. For this example, the problem is
due to the missing ``debootstrap`` binary.

So you have to install it on your ``out`` context (to read more about context
see the :doc:`context` page). Just type the ``o`` key and ``Enter``. Now you
are logged in your out context. If you are on a Debian based system install the
missing package::

    (out_context) root@f4b261b5fad7: ~/build/my_debian # sudo apt-get install debootstrap

Press ``Ctrl-d`` or type ``exit`` to go back to the Kameleon prompt then press
``c`` and ``Enter`` to continue the build.

The first time it will take a while to finish the building process. But, Thanks
to the :doc:`checkpoint` mechanism you can abort with ``Ctrl-c`` anytime during
the build without problem.

Every step is backed up and if you start the build again, it will skip all the
steps already done to restart at the point you have just stopped.

Moreover, if you change anything in the recipe Kameleon will know it (using
recipe and steps hashes), so your next build will automatically restart at the
right steps. Here is a good example: The first time you built your recipe you
should have something like this::

    ...
    [kameleon]: Build recipe 'my_debian.yaml' is completed !
    [kameleon]: Build total duration : 224 secs
    ...

Now you can run your appliance using qemu::

    qemu-system-x86_64 -enable-kvm builds/my_debian/my_debian.qcow2

.. note::
    If you do not have access to a graphical server use the ``-curses`` option

How to use the checkpoint
~~~~~~~~~~~~~~~~~~~~~~~~~

You just have to run the build again and you will notice that it is much faster::

    kameleon build my_debian
    ...
    [kameleon]: Step 1 : bootstrap/_init_bootstrap/_init_0_debootstrap
    [kameleon]:  ---> Using cache
    ...
    [kameleon]: Build recipe 'my_debian' is completed !
    [kameleon]: Build total duration : 22 secs
    ...

As you can see Kameleon has used the checkpoint cache for each step and in
doing so it takes just 22 seconds to build the recipe again. Well the recipe
did not change so there is no real challenge to build it so fast. Let's change
the user name for example. Open the ``my_debian.yaml`` recipe file and in the
global section change the user name like this::

    user_name: my_user

Save the file and re-build the recipe again. This is a part of the outputs you
should see::

    kameleon build my_debian
    ...
    [kameleon]: Step 29 : setup/create_user/create_group
    [kameleon]:  ---> Using cache
    [kameleon]: Step 30 : setup/create_user/add_user
    [kameleon]:  ---> Running step
    [kameleon]:  ---> Creating checkpoint : 6bde599e7ed1
    [kameleon]: Step 31 : setup/create_user/add_group_to_sudoers
    [kameleon]:  ---> Running step
    [kameleon]:  ---> Creating checkpoint : 28b7a1fae5e2
    ...
    [kameleon]: Build recipe 'my_debian' is completed !
    [kameleon]: Build total duration : 29 secs
    ...

This need a little explanation: You have change the ``user_name`` value in the
recipe. This variable is firstly used in the ``add_user`` :ref:`microstep`, in
the create_user :ref:`step` within the setup section.

That is why allmicrosteps before this one (the 30 in our case) are using the
cache but all the microsteps after are build again, to prevent side effects of
this change, even if they are not using the ``add_user`` value.

Add a new step
~~~~~~~~~~~~~~

Let's assume that you want to add a step to put a timestamp in your image to
know when it was built. First, you have to create a step file in the
``steps/setup`` folder because you want your timestamp to be added inside the
newly created appliance before exporting it.

Let's call it ``add_timestamp.yaml``:

.. literalinclude:: ../../contrib/steps/setup/add_timestamp.yaml
    :language: yaml

Then you should have this step to the recipe at the end of the setup section::

    ...
    setup:
        ...
        - add_timestamp

Then build again your recipe and run it like before to see that your timestamp
has been truly added.
To get more information about steps definition and usage like default
variable and microstep selection see :ref:`step`.

Advanced Features
~~~~~~~~~~~~~~~~~

Kameleon gives you a lot of extension and customization possibilities. You can
define you own :doc:`aliases` and even your own :doc:`checkpoint` mechanism. You
are invited to go through the rest of the documentation to fully understand
Kameleon and it's great possibilities.
