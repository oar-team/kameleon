---------------
Getting Started
---------------

.. note::
    This page is a work in progress...

To install Kameleon have a look at the :doc:`installation` section.

First thing to know is that Kameleon is an automation tool for bash. It brings
the ease of error handling, retry, checkpointing, easy debugging and cleaning
to your scripts to help you to build your software appliance.

The template system built-in allows you quickly build a system and to understand the
Kameleon basics. Let see the template list:
::
    kameleon templates

It shows the templates names and descriptions directly from the templates files shipped
with  Kameleon:
::
    The following templates are available in /var/lib/gems/1.9.1/gems/kameleon-builder-2.0.0/templates:
    NAME                 | DESCRIPTION
    ---------------------|-----------------------------------------------------------
    fedora-docker        | Fedora base image [Work in progress].
    debian-wheezy-chroot | Build a debian wheezy appliance using chroot and qemu-nbd.
    debian-wheezy-docker | Build a debian wheezy appliance using Docker.

Let's pick one of these. The `debian-wheezy-chroot` is a good example. Now you
will create a new recipe from this template.  Let's name it `debian_test`.
::
    kameleon new debian_test -t debian-wheezy-chroot

Actually, Kameleon make a direct copy of the YAML template recipe file and all
the other required files like steps or aliases ones. You can see that in the
`new` command output:
::
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

You can check that you got all the files in your workspace:

::

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

.. note::
    Be sure to be `root` to run the following steps. It is needed for loading
    modules, chrooting,...

There is no magic computation in Kameleon everything is written in YAML files:
from your system bootstrap to his export. It empowers you to customize anything
you want at anytime during the appliance build. But before changing anything
just build the template to see how it works:
::
     kameleon build debian_test

Oups! Maybe you got an error like this:
::
    ...
    [engine]: qemu-img is missing
    [engine]: Press [c] to continue with execution
    [engine]: Press [a] to abort execution
    [engine]: Press [l] to switch to local_context shell
    [engine]: Press [o] to switch to out_context shell
    [engine]: answer ? [c/a/l/o]:

This is the interactive prompt of Kameleon. It is a powerfull tool because if
something wrong happen anytime during the build process it appears and give you
a chance to fix the problem.
For now, the problem is that the `qemu-img` is missing. So you have to install it on your `out` context (to read more about context see the :doc:`context` page). Just push the `o` button and `Enter`. Now you are logged in your out context. If you are on a Debian based system install the missing package:
::
    apt-get install qemu-utils

Press `Ctrl-d` or type `exit` to go back to the Kameleon prompt and press `c` and `Enter` to continue the build.

The first time it will take a while...

Using the :doc:`context` notion, it also manage the connection to your new
appliance and make it easy and reliable.


