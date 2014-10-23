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

Kameleon is delivered without any template by default. To begin, a recipe
repository has to be added::

    $ kameleon template repo add default https://github.com/oar-team/kameleon-recipes.git
    $ kameleon template list

It shows the templates names and descriptions directly from the templates files shipped
with  Kameleon::

    The following templates are available in /home/salem/.kameleon.d/repos:
    NAME                           | DESCRIPTION
    -------------------------------|------------------------------------------------------------
    default/base/archlinux         | Base template for Archlinux appliance.
    default/base/centos            | Base template for Centos appliance.
    default/base/debian            | Base template for Debian appliance.
    default/base/fedora            | Base template for Fedora appliance.
    default/base/ubuntu            | Base template for Ubuntu appliance.
    default/chroot/debian7         | Debian 7 (Wheezy) appliance built with chroot and qemu-nbd.
    default/docker/debian7         | Debian base image for docker built with docker.
    default/grid5000/debian7       | Debian 7 (Wheezy) image built with Grid5000 platform.
    default/qemu/archlinux         | Archlinux base system built with qemu-kvm.
    default/qemu/centos6.5         | Centos 6.5 base system built with qemu-kvm.
    default/qemu/centos7           | Centos 7 base system built with qemu-kvm.
    default/qemu/debian7           | Debian 7 (Wheezy) base system built with qemu-kvm.
    default/qemu/debian8           | Debian 8 (Jessie) base system built with qemu-kvm.
    default/qemu/fedora20          | Fedora 20 base system built with qemu-kvm.
    default/qemu/ubuntu12.04       | Ubuntu 12.04 LTS base system built with qemu-kvm.
    default/qemu/ubuntu14.04       | Ubuntu 14.04 LTS base system built with qemu-kvm.
    default/vagrant/centos6.5      | A standard Centos 6.5 vagrant base box.
    default/vagrant/debian7        | A standard Debian 7 vagrant base box.
    default/vagrant/debian8        | A standard Debian 8 vagrant base box.
    default/virtualbox/archlinux   | Archlinux base system built with virtualbox.
    default/virtualbox/centos6.5   | Centos 6.5 base system built with virtualbox.
    default/virtualbox/centos7     | Centos 7 base system built with virtualbox.
    default/virtualbox/debian7     | Debian 7 (Wheezy) base system built with virtualbox.
    default/virtualbox/debian8     | Debian 8 (Jessie) base system built with virtualbox.
    default/virtualbox/fedora20    | Fedora 20 base system built with virtualbox.
    default/virtualbox/ubuntu12.04 | Ubuntu 12.04 LTS base system built with virtualbox.
    default/virtualbox/ubuntu14.04 | Ubuntu 14.04 LTS base system built with virtualbox.

Let's pick one of these. The ``debian7`` is a good example. Now you
will create a new recipe from this template.  Let's name it ``my_debian``::

    kameleon new my_debian default/qemu/debian7

Kameleon make a direct copy of the YAML template recipe file and all
the other required files like steps or aliases ones. You can see that in the
``new`` command output::

      create  default/qemu/debian7.yaml
      create  default/base/debian.yaml
      create  default/steps/aliases/defaults.yaml
      create  default/steps/checkpoints/qemu.yaml
      create  default/steps/bootstrap/prepare_qemu.yaml
      create  default/steps/bootstrap/start_qemu.yaml
      create  default/steps/enable_checkpoint.yaml
      create  default/steps/bootstrap/install_requirements.yaml
      create  default/steps/bootstrap/initialize_disk.yaml
      create  default/steps/bootstrap/debian/debootstrap.yaml
      create  default/steps/bootstrap/reboot_qemu.yaml
      create  default/steps/setup/debian/configure_apt.yaml
      create  default/steps/setup/debian/upgrade_system.yaml
      create  default/steps/setup/debian/install_software.yaml
      create  default/steps/setup/debian/configure_kernel.yaml
      create  default/steps/setup/debian/install_bootloader.yaml
      create  default/steps/setup/debian/configure_system.yaml
      create  default/steps/setup/debian/configure_keyboard.yaml
      create  default/steps/setup/debian/configure_network.yaml
      create  default/steps/setup/create_group.yaml
      create  default/steps/setup/create_user.yaml
      create  default/steps/disable_checkpoint.yaml
      create  default/steps/export/qemu_save_appliance.yaml
      create  my_debian7.yaml

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

     kameleon build my_debian.yaml

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

    kameleon build my_debian.yaml
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
