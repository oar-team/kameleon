---------------
Getting Started
---------------

Installation
~~~~~~~~~~~~

To install Kameleon, have a look at the :doc:`installation` section.

Create a new recipe from template
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Kameleon can be seen as a shell sequencer which will boost your shell scripts.
It is based on the execution of shell scripts but it also provides some syntax sugar
that makes working with shell scripts less painful.

Kameleon is delivered without any template by default::

    $ kameleon template list

To begin, a recipe repository has to be added::

    $ kameleon template repo add default https://github.com/oar-team/kameleon-recipes.git
    $ kameleon template list

Now, you should see the template list prefixed by the repository name, called
"default"::

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

To build a Debian 7 image, it is possible to choose from several virtualization
tools: chroot, qemu, virtualbox, etc.

In this tutorial, we are going to choose qemu. Let's import the debian7
template in our workspace::

    $ mkdir my_recipes && cd my_recipes  ## create a workspace
    $ kameleon new my_debian7 default/qemu/debian7


Kameleon make a direct copy of the YAML template recipe file and all
other required files such as steps or aliases. You can see that in the
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

To understand this hierarchy, please refer to the :doc:`recipe` documentation.

We have thus the following recipes in our ``workspace``::

    $ kameleon list
    NAME                 | DESCRIPTION
    ---------------------|---------------------------------------------------
    default/base/debian  | Base template for Debian appliance.
    default/qemu/debian7 | Debian 7 (Wheezy) base system built with qemu-kvm.
    my_debian7           | <MY RECIPE DESCRIPTION>


The new recipe ``my_debian7.yaml`` inherits the base recipe
``default/qemu/debian7.yaml`` as we can see in the
``my_debian7.yaml`` file with the keyword ``extend``

.. code-block:: yaml
   :linenos:
   :emphasize-lines: 10,17,20,23

    #==============================================================================
    # vim: softtabstop=2 shiftwidth=2 expandtab fenc=utf-8 cc=81 tw=80
    #==============================================================================
    #
    # DESCRIPTION: <MY RECIPE DESCRIPTION>
    #
    #==============================================================================

    ---
    extend: default/qemu/debian7.yaml

    global:
        # You can view the base template `default/qemu/debian7.yaml` to find
        # out which variables you can override

    bootstrap:
      - "@base"

    setup:
      - "@base"

    export:
      - "@base"

This recipe acts exactly as the parent recipe thanks to the keyword
``"@base"``. (see :ref:`inheritance`)

Build my new recipe
~~~~~~~~~~~~~~~~~~~

There is no magic in Kameleon, everything is written in YAML, from your system
bootstrap to its export. It empowers you to customize anything you want at
anytime during the appliance build. But before changing anything, just build the
template to see how it works::

    $ kameleon build my_debian7.yaml --enable-cache

.. note::
  We enable caching all network data that will be used to build the appliance.
  Thanks to this, the recipe reconstructability is ensured (see
  :ref:`persistent_cache`)

Oops! Maybe you get an error like this one::

    ...
    socat is missing from local_context
    Press [c] to continue with execution
    Press [a] to abort execution
    Press [l] to switch to local_context shell
    Press [o] to switch to out_context shell
    Press [i] to switch to in_context shell
    answer ? [c/a/l/o/i]:


It is a powerful tool that offers the possibility to fix a problem if
something goes wrong during the build process. In this example, the problem is
due to the missing ``socat`` binary.

So you have to install it on your ``local`` context (to read more about context
see the :doc:`context` page). Just type the ``l`` key and ``Enter``. Now you
are logged in your local context. If you are on a Debian based system install
the missing package::

    (local_context) salem@myhost: ~/build/my_debian7 $ sudo apt-get install socat

Press ``Ctrl-d`` or type ``exit`` to go back to the Kameleon prompt then press
``c`` and ``Enter`` to continue the build.

When Kameleon ends, a directory called ``build`` will be generated in the
current directory. You will have a debian wheezy appliance that you can try out
by executing::

    $ qemu-system-x86_64 -enable-kvm -m 512 build/my_debian7/my_debian7.qcow2

.. note::
    If you do not have access to a graphical server use the ``-curses`` option

Add a new step
~~~~~~~~~~~~~~

Let's assume that you want to add a step to put a timestamp in your image to
know when it was built. First, you have to create a step file in the
``steps/setup`` folder because you want your timestamp to be added inside the
newly created appliance before exporting it.

Let's call it ``add_timestamp.yaml``:

.. literalinclude:: ../../contrib/steps/setup/add_timestamp.yaml
    :language: yaml

Then you should add this step to the recipe at the end of the setup section::

    ...
    setup:
        ...
        - add_timestamp

Then build again your recipe and run it like before to see that your timestamp
has been truly added.
To get more information about step definition and the use of default
variable and microstep selection, see :ref:`step`.

Advanced Features
~~~~~~~~~~~~~~~~~

Kameleon gives you a lot of extension and customization possibilities. You can
define your own :doc:`aliases` and even your own :doc:`checkpoint` mechanism.
You are invited to go through the rest of the documentation to fully understand
Kameleon and its great possibilities.
