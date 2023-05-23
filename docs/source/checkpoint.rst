.. _`checkpoint`:

----------
Checkpoint
----------

How to use the checkpoints
==========================

Kameleon can use a checkpointing mechanism to save the build progress step
after step. This mechanism allows to work with Kameleon more serenely as it
avoids the need to build from scratch everytime, which is expecially useful
when some steps last very long. Build can restart from a later step. This is
very useful when writing a new recipe that involves a lot of trials and errors.

The checkpointing mechanism is disabled by default. It must be enabled
explicitely when building:

    kameleon build my_debian7.yaml --enable-checkpoint

.. note::
    it is also possible to combine the persistent cache and the checkpoints by
    adding ``--enable-cache``

Then, for every step, a message indicates that a checkpoint has been created to save
the progression::

    ...
    [out] I: Configuring initramfs-tools...
    [out] I: Base system installed successfully.
    --> Creating checkpoint : 980e9a33575f

Every checkpoint has a unique identifier. You can list all the available
checkpoints::

    $ kameleon build --checkpoints my_debian7.yaml
    The following checkpoints are available for  the recipe 'my_debian7':
    ID           | STEP
    -------------|-----------------------------------------------------
    fb008f91d796 | bootstrap/install_requirements/apt_install
    6deac03c483b | bootstrap/initialize_disk/partition_disk
    2457e1aa2a3f | bootstrap/initialize_disk/mount_mountdir
    980e9a33575f | bootstrap/debootstrap/debootstrap
    6749dc619042 | bootstrap/reboot_qemu/prepare_sshd
    e2d17199fde0 | bootstrap/reboot_qemu/mount_chroot
    d9acd4246149 | bootstrap/reboot_qemu/create_fstab
    b094cef7d7be | bootstrap/reboot_qemu/install_initial_bootloader
    34177dbbb620 | bootstrap/reboot_qemu/umount_all
    108a6e403e8b | bootstrap/reboot_qemu/switch_out2in
    3653c6e4eec5 | setup/configure_apt/configure_source_list
    75843bf617f6 | setup/configure_apt/add_contribs_and_nonfree_sources
    b26459bf60c2 | setup/configure_apt/update_repositories
    b02b52c901a2 | setup/upgrade_system/upgrade_system
    5f5ae8929eb7 | setup/install_software/core_packages
    a49db885718b | setup/configure_kernel/configure_kernel
    51c4dcd46db4 | setup/configure_kernel/update_initramfs
    c98c61f19e98 | setup/install_bootloader/install_extlinux
    3076e23b76a6 | setup/configure_system/configure_locales
    56fcb300ea46 | setup/configure_system/set_timezone
    3235dce67d3b | setup/configure_keyboard/keyboard_config
    a1d62699acfa | setup/configure_network/network_interfaces
    f504f10643b0 | setup/configure_network/set_hosts
    373789dae955 | setup/configure_network/set_hostname
    07f4ef30d403 | setup/create_group/create_group
    fb0623a2d1c6 | setup/create_user/add_user
    7e4c40ce138a | setup/create_user/add_to_groups
    fe6db526b96b | setup/_clean_setup/_clean_2_update_repositories
    03a61dc909b8 | setup/_clean_setup/_clean_1_prepare_sshd

You can relaunch the build starting from a specific checkpoint. For instance,
to resume the build from the ``setup/configure_network/network_interfaces``
step, we launch the build from the previous checkpoint.

.. code-block:: bash
   :emphasize-lines: 1

    3235dce67d3b | setup/configure_keyboard/keyboard_config
    a1d62699acfa | setup/configure_network/network_interfaces


.. code-block:: bash
   :emphasize-lines: 19

    $ kameleon build my_debian7.yaml --from-checkpoint 3235dce67d3b
    ...
    Step 25 : setup/configure_kernel/update_initramfs
    --> Using checkpoint
    Step configure_kernel took: 0 secs
    Step 26 : setup/install_bootloader/install_extlinux
    --> Using checkpoint
    Step install_bootloader took: 0 secs
    Step 27 : setup/configure_system/configure_locales
    --> Using checkpoint
    Step configure_system took: 0 secs
    Step 28 : setup/configure_system/set_timezone
    --> Using checkpoint
    Step configure_system took: 0 secs
    Step 29 : setup/configure_keyboard/keyboard_config
    --> Using checkpoint
    Step configure_keyboard took: 0 secs
    Step 30 : setup/configure_network/network_interfaces
    --> Running the step...
    Starting process: "ssh -F /home/salem/.tmp/kameleon_X3i/build/my_debian7/ssh_config my_debian7 -t /bin/bash"
    [in] The in_context has been initialized
    --> Creating checkpoint : a1d62699acfa
    [local] QEMU 2.1.2 monitor - type 'help' for more information
    [local] (qemu) savevm a1d62699acfa
    Step configure_network took: 1 secs
    Step 31 : setup/configure_network/set_hosts
    --> Running the step...
    --> Creating checkpoint : f504f10643b0
    ...

    Successfully built 'my_debian7.yaml'
    Total duration : 33 secs


As you can see, Kameleon used the checkpoint cache for each step and it took
only 24 seconds to rebuild from the recipe. Actually, the recipe did not change
so there is no real challenge to build it so fast. Let's change the user name
for example. Open the ``my_debian.yaml`` recipe file and in the global section
change the user name as shown below::

    user_name: my_user

Save the file and re-build the recipe::

    $ kameleon build my_debian7.yaml --from-checkpoint last

Here are some outputs you should see::

    Step 33 : setup/create_group/create_group
    --> Using checkpoint
    Step create_group took: 0 secs
    Step 34 : setup/create_user/add_user
    --> Running the step...
    ...
    Successfully built 'my_debian7.yaml'
    Total duration : 25 secs

This needs a little explanation: you have changed the ``user_name`` value in the
recipe. This variable is firstly used in the ``add_user`` :ref:`microstep`, in
the create_user :ref:`step` within the setup section.

That is why all steps before this one (the 34 in our case) are using the
cache but all the steps after are built again, to prevent side effects of
this change, even if they are not using the ``add_user`` value.

Define how steps handle checkpoints in recipes
==============================================
For every microstep, the checkpoint action can be defined with the ``on_checkpoint`` key, using the following values:

use_cache
    The microstep will use a previous checkpoint if it exists. This is the default.

redo
    The microstep will not be checkpointed, it will be done (or redone) every time.

skip
    The microstep will not be run when checkpointing is enabled (even when not step was ever checkpointed).

Please also note that the ``kameleon build`` command provides an option named ``--microstep-checkpoint`` that allows to limit the checkpoint creation to the first microstep of every macrostep.

Develop your own checkpoint mechanism
=====================================

While some checkpointing mechanisms are already available in the default
Kameleon recipes, Kameleon actually allows to implement custom checkpointing
mechanisms, using for instance the snapshoting features of any filesystem or
VM/container engine.

Kameleon checkpointing mechanisms are actually defined as part of the recipe
files, in the ``steps/checkpoints`` directory.

A checkpointing mechanism must provide serveral hooks that are actually defined
using the recipe step syntax. Hooks are the following:

enabled?
    Check whether the build process is ready to create/use checkpoints at the current step.

create
    Define the steps to create a checkpoint.

apply
    Define the step to apply a checkpoint and continue the build from it.

clear
    Remove all checkpoints.

list
    List the available checkpoints and associated steps.

The current microstep identifier can be used in your hooks, using the
``@microstep_id`` keyword.

Then the Kameleon recipe defines the checkpoint mechanism to use using the
``checkpoint`` key in the main recipe file.  Value to set is the file name of
the YAML file which defines mechanism. For instance:: ``checkpoint:
custom_checkpoint.yaml`` if the custom checkpointing mechanism is defined in
``steps/checkpoints/custom_checkpoint.yaml``.

The following example is a very simple checkpoint implementation:

.. code-block:: yaml

    enabled?:
      - exec_local: test -f $KAMELEON_WORKDIR/list_checkpoints.txt

    create:
      - exec_local: echo @microstep_id >> $KAMELEON_WORKDIR/list_checkpoints.txt

    apply:
      - exec_local: echo "restore to @microstep_id"

    list:
      - exec_local: cat $KAMELEON_WORKDIR/list_checkpoints.txt

    clear:
      - exec_local: rm -f $KAMELEON_WORKDIR/list_checkpoints.txt
