---------------
Getting Started
---------------

.. note::
    This page is a work in progress...

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
    fedora-docker        | Fedora base image [Work in progress].
    debian-wheezy-chroot | Build a debian wheezy appliance using chroot and qemu-nbd.
    debian-wheezy-docker | Build a debian wheezy appliance using Docker.

Let's pick one of these. The ``debian-wheezy-chroot`` is a good example. Now you
will create a new recipe from this template.  Let's name it ``debian_test``::

    kameleon new debian_test -t debian-wheezy-chroot

Kameleon make a direct copy of the YAML template recipe file and all
the other required files like steps or aliases ones. You can see that in the
``new`` command output::

   [cli]: Cloning template 'debian-wheezy-chroot'
   [recipe]: Loading /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/debian-wheezy-chroot.yaml
   [recipe]: Loading aliases /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/aliases/defaults.yaml
   [recipe]: Loading checkpoint configuration /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/checkpoints/qcow2.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/bootstrap/debian/debootstrap.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/bootstrap/prepare_appliance_with_nbd.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/bootstrap/start_chroot.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/setup/debian/software_install.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/setup/debian/kernel_install.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/setup/debian/system_config.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/setup/debian/keyboard_config.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/setup/debian/network_config.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/setup/create_user.yaml
   [recipe]: Loading macrostep /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates/steps/export/save_appliance_from_nbd.yaml
   [recipe]: Loading recipe metadata
      [cli]: New recipe "debian_test" as been created in /home/mercierm/kameleon_ws/recipes/debian_test.yaml

You can check that you got all the files in your workspace for example with the
UNIX ``tree`` command::

    tree
    .
    `-- recipes
        |-- aliases
        |   `-- defaults.yaml
        |-- checkpoints
        |   `-- qcow2.yaml
        |-- debian_test.yaml
        `-- steps
            |-- bootstrap
            |   |-- debian
            |   |   `-- debootstrap.yaml
            |   |-- prepare_appliance_with_nbd.yaml
            |   `-- start_chroot.yaml
            |-- export
            |   `-- save_appliance_from_nbd.yaml
            `-- setup
                |-- create_user.yaml
                `-- debian
                    |-- kernel_install.yaml
                    |-- keyboard_config.yaml
                    |-- network_config.yaml
                    |-- software_install.yaml
                    `-- system_config.yaml
    
    9 directories, 13 files

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

     kameleon build debian_test

Oups! Maybe you get an error like this::

    ...
    [engine]: qemu-img is missing
    [engine]: Press [c] to continue with execution
    [engine]: Press [a] to abort execution
    [engine]: Press [l] to switch to local_context shell
    [engine]: Press [o] to switch to out_context shell
    [engine]: answer ? [c/a/l/o]:

This is the interactive prompt of Kameleon. 
It is a powerful tool that offers you the possibility to fix a problem
if something goes wrong during the build process.
For this example, the problem is due to the missing ``qemu-img`` binary. 
So you have to install it on your ``out`` context (to read more about context see the
:doc:`context` page). Just type the ``o`` key and ``Enter``. Now you are logged
in your out context. If you are on a Debian based system install the missing
package::

    apt-get install qemu-utils

Press ``Ctrl-d`` or type ``exit`` to go back to the Kameleon prompt then press
``c`` and ``Enter`` to continue the build.

The first time it will take a while to finish the building process. But, Thanks
to the :doc:`checkpoint` mechanism you can abort with ``Ctrl-c`` anytime during
the build without problem. Every step is backed up and if you start the
build again, it will skip all the steps already done 
to restart at the point you have just stopped. Moreover, if you change anything in the recipe
Kameleon will know it (using recipe and steps hashes), so your next build will
automatically restart at the right steps. Here is a good example: The first
time you built your recipe you should have something like this::

    ...
    [cli]: Build recipe 'debian_test' is completed !
    [cli]: Build total duration : 424 secs
    ...

Now you can run your appliance using qemu::

    qemu-system-x86_64 -enable-kvm builds/debian_test/debian_test.qcow2

.. note::
    If you do not have access to a graphical server use the ``-curses`` option

How to use the checkpoint
~~~~~~~~~~~~~~~~~~~~~~~~~

You just have to run the build again and you will notice that it is much faster::

    kameleon build debian_test
    ...
    [engine]: Step 1 : bootstrap/_init_bootstrap/_init_0_debootstrap
    [engine]:  ---> fac7c7045b6f
    [engine]:  ---> Using cache
    ...
    [cli]: Build recipe 'debian_test' is completed !
    [cli]: Build total duration : 4 secs
    ...

As you can see Kameleon has used the checkpoint cache for each step and in
doing so it takes just 4 seconds to build the recipe again. Well the recipe did
not change so there is no real challenge to build it so fast. Let's change
the user name for example. Open the ``debian_test.yaml`` recipe file and in the
global section change the user name like this::

    user_name: my_user

Save the file and re-build the recipe again. This is a part of the outputs you
should see::

    kameleon build debian_test
    ...
    [engine]: Step 29 : setup/create_user/create_group
    [engine]:  ---> ad19db198510
    [engine]:  ---> Using cache
    [engine]: Step 30 : setup/create_user/add_user
    [engine]:  ---> 6bde599e7ed1
    [engine]:  ---> Running step
    [engine]:  ---> Creating checkpoint : 6bde599e7ed1
    [engine]: Step 31 : setup/create_user/add_group_to_sudoers
    [engine]:  ---> 28b7a1fae5e2
    [engine]:  ---> Running step
    [engine]:  ---> Creating checkpoint : 28b7a1fae5e2 
    ...
    [cli]: Build recipe 'debian_test' is completed !
    [cli]: Build total duration : 29 secs
    ...

This need a little explanation: You have change the ``user_name`` value in the
recipe. This variable is firstly used in the ``add_user`` :ref:`microstep`, in the
create_user :ref:`step` within the setup section. That is why all microsteps
before this one (the 30 in our case) are using the cache but all the microsteps after
are build again, to prevent side effects of this change, even if they are not
using the ``add_user`` value.

Add a new step
~~~~~~~~~~~~~~

Let's assume that you want to add a step to put a timestamp in your image to
know when it was built. First, you have to create a step file in the
``steps/setup`` folder because you want your timestamp to be added inside the
newly created appliance before exporting it. Let's call it ``add_timestamp.yaml``:

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
