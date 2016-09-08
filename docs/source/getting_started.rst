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

Kameleon is delivered without any template by default:

.. code-block:: bash

    kameleon template list

To begin, a recipe repository has to be added:

.. code-block:: bash

    kameleon template repo add default https://github.com/oar-team/kameleon-recipes.git
    kameleon template list

Now, you should see the template list prefixed by the repository name, called
"default":

.. code-block:: bash

    The following templates are available in /home/mercierm/.kameleon.d/repos:
    NAME                                       | DESCRIPTION                                                             
    -------------------------------------------|-------------------------------------------------------------------------
    default/from_image/archlinux               | Archlinux full system recipe                                            
    default/from_image/centos6                 | Centos 6 base system.                                                   
    default/from_image/centos7                 | Centos 6 base system.                                                   
    default/from_image/debian7                 | Debian 7 (Wheezy) appliance.                                            
    default/from_image/debian8                 | Debian 8 (Jessie) base system.                                          
    default/from_image/fedora20                | Fedora 20 base system.                                                  
    default/from_image/fedora21                | Fedora 21 base system.                                                  
    default/from_image/fedora22                | Fedora 22 base system.                                                  
    default/from_image/from_tarball            | Simple recipe that only import a tarball images like provided by here...
    default/from_image/kameleon_tutorial       | Debian 8 + Kameleon tools for Grid5000 tutorial.                        
    default/from_image/ubuntu12.04             | Ubuntu 12.04 LTS base system.                                           
    default/from_image/ubuntu14.04             | Ubuntu 14.04 LTS base system.                                           
    default/from_scratch/archlinux             | Archlinux base system.                                                  
    default/from_scratch/centos6               | Centos 6 base system.                                                   
    default/from_scratch/centos7               | Centos 7 base system.                                                   
    default/from_scratch/debian-debootstrap    | Debian generic recipe + debootstrap.                                    
    default/from_scratch/debian-sid            | Debian sid base system.                                                 
    default/from_scratch/debian-testing        | Debian testing base system.                                             
    default/from_scratch/debian7               | Debian 7 (Wheezy) base system.                                          
    default/from_scratch/debian8               | Debian 8 (Jessie) base system.                                          
    default/from_scratch/debian8-arm64         | Debian 8 (Jessie) system for arm64 + qemu-user-static.                  
    default/from_scratch/fedora20              | Fedora 20 base system.                                                  
    default/from_scratch/fedora21              | Fedora 21 base system.                                                  
    default/from_scratch/fedora22              | Fedora 22 base system.                                                  
    default/from_scratch/fedora23              | Fedora 23 base system.                                                  
    default/from_scratch/ubuntu-base-bootstrap | Ubuntu 12.04 LTS base system.                                           
    default/from_scratch/ubuntu12.04           | Ubuntu 12.04 LTS base system.                                           
    default/from_scratch/ubuntu14.04           | Ubuntu 14.04 LTS base system.                                           

To build a Debian 8 image, it is possible to choose from several virtualization
tools: chroot, qemu, virtualbox, etc.

In this tutorial, we are going to choose qemu (which is the default one).
Let's import the Debian 8 template in our workspace:

.. code-block:: bash

    mkdir my_recipes && cd my_recipes  ## create a workspace
    kameleon new my_debian8 default/from_image/debian8

.. note::
	If you want to use an other backend, for example virtualbox use the
	option ``--global backend:virtualbox`` on the previous command.

Kameleon make a direct copy of the YAML template recipe file and all
other required files such as steps or aliases. You can see that in the
``new`` command output:

.. code-block:: bash

      create  default/from_image/debian8.yaml
      create  default/from_image/debian7.yaml
      create  default/from_image/base.yaml
      create  default/steps/backend/qemu.yaml
      create  default/steps/backend/VM.yaml
      create  default/steps/global/qemu_options.yaml
      create  default/steps/aliases/defaults.yaml
      create  default/steps/checkpoints/qemu.yaml
      create  default/steps/bootstrap/create_appliance.yaml
      create  default/steps/bootstrap/prepare_appliance.yaml
      create  default/steps/bootstrap/start_qemu.yaml
      create  default/steps/setup/debian/configure_apt.yaml
      create  default/steps/setup/debian/upgrade_system.yaml
      create  default/steps/setup/debian/install_software.yaml
      create  default/steps/setup/debian/configure_system.yaml
      create  default/steps/setup/debian/configure_keyboard.yaml
      create  default/steps/setup/debian/configure_network.yaml
      create  default/steps/setup/kameleon_customization.yaml
      create  default/steps/setup/create_user.yaml
      create  default/steps/setup/debian/clean_system.yaml
      create  default/steps/disable_checkpoint.yaml
      create  default/steps/export/save_appliance_VM.yaml
      create  default/steps/data/helpers/create_appliance.py
      create  default/steps/data/skel/.bashrc
      create  default/steps/data/skel/.vimrc
      create  default/steps/data/skel/.pythonrc.py
      create  default/steps/data/helpers/export_appliance.py
      create  default/steps/env/bashrc
      create  default/steps/env/functions.sh
      create  my_debian8.yaml

To understand this hierarchy, please refer to the :doc:`recipe` documentation.

We have thus the following recipes in our ``workspace``:

.. code-block:: yaml

    kameleon list
    NAME                       | DESCRIPTION                   
    ---------------------------|-------------------------------
    default/from_image/debian7 | Debian 7 (Wheezy) appliance.  
    default/from_image/debian8 | Debian 8 (Jessie) base system.
    my_debian8                 | <MY RECIPE DESCRIPTION> 

The new recipe ``my_debian8.yaml`` inherits the base recipe
``default/from_image/debian8.yaml`` as we can see in the
``my_debian8.yaml`` file with the keyword ``extend``.

.. code-block:: yaml
  :linenos:
  :emphasize-lines: 9,25,28,31

  #==============================================================================
  # vim: softtabstop=2 shiftwidth=2 expandtab fenc=utf-8 cc=81 tw=80
  #==============================================================================
  #
  # DESCRIPTION: <MY RECIPE DESCRIPTION>
  #
  #==============================================================================
  ---
  extend: default/from_image/debian8.yaml

  global:
    # This is the backend you have imported to switch to an other backend BCKD do:
    #
    #   kameleon template import default/from_image/debian8.yaml --global backend:BCKB
    #
    # and uncomment update the following variable.

    # backend: qemu %>

    # To see the variables that you can override, use the following command:
    #
    #   kameleon info my_debian8.yaml

  bootstrap:
    - "@base"

  setup:
    - "@base"

  export:
    - "@base"


This recipe inherits from the parent recipe thanks to the keyword ``"@base"``.
See :ref:`inheritance` for more details.

An other very useful command is ``kameleon info`` it show a nice colorful
output that shows you every information about on or several recipes. For example:

.. code-block:: bash

    kameleon info my_debian8.yaml
    --------------------
    [Name]
     -> my_debian8
    [Path]
     -> /home/mercierm/my_recipes/my_debian8.yaml
    [Description]
     -> <MY RECIPE DESCRIPTION>
    [Parent recipes]
     -> /home/mercierm/my_recipes/default/from_image/debian8.yaml
     -> /home/mercierm/my_recipes/default/from_image/debian7.yaml
     -> /home/mercierm/my_recipes/default/from_image/base.yaml
     -> /home/mercierm/my_recipes/default/steps/backend/qemu.yaml
     -> /home/mercierm/my_recipes/default/steps/backend/VM.yaml
    [Steps]
     -> /home/mercierm/my_recipes/default/steps/global/qemu_options.yaml
     -> /home/mercierm/my_recipes/default/steps/aliases/defaults.yaml
     -> /home/mercierm/my_recipes/default/steps/checkpoints/qemu.yaml
     -> /home/mercierm/my_recipes/default/steps/bootstrap/create_appliance.yaml
     -> /home/mercierm/my_recipes/default/steps/bootstrap/prepare_appliance.yaml
     -> /home/mercierm/my_recipes/default/steps/bootstrap/start_qemu.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/debian/configure_apt.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/debian/upgrade_system.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/debian/install_software.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/debian/configure_system.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/debian/configure_keyboard.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/debian/configure_network.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/kameleon_customization.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/create_user.yaml
     -> /home/mercierm/my_recipes/default/steps/setup/debian/clean_system.yaml
     -> /home/mercierm/my_recipes/default/steps/disable_checkpoint.yaml
     -> /home/mercierm/my_recipes/default/steps/export/save_appliance_VM.yaml
    [Data]
     -> /home/mercierm/my_recipes/default/steps/data/helpers/create_appliance.py
     -> /home/mercierm/my_recipes/default/steps/data/skel/.bashrc
     -> /home/mercierm/my_recipes/default/steps/data/skel/.vimrc
     -> /home/mercierm/my_recipes/default/steps/data/skel/.pythonrc.py
     -> /home/mercierm/my_recipes/default/steps/data/helpers/export_appliance.py
    [Environment scripts]
     -> /home/mercierm/my_recipes/default/steps/env/bashrc
     -> /home/mercierm/my_recipes/default/steps/env/functions.sh
    [Variables]
     -> appliance_filename: /home/mercierm/build/my_debian8/my_debian8
     -> appliance_formats: qcow2 tar.gz
     -> appliance_tar_compression_level: 9
     -> appliance_tar_excludes: ./etc/fstab ./root/.bash_history ./root/kameleon_workdir ./root/.ssh ./var/tmp/* ./tmp/* ./var/log/* ./dev/* ./proc/* ./run/* ./sys/*
     -> apt_enable_contrib: true
     -> apt_enable_nonfree: true
     -> apt_repository: http://ftp.debian.org/debian/
     -> arch: x86_64
     -> backend: qemu
     -> default_keyboard_layout: us,fr,de
     -> default_lang: en_US.UTF-8
     -> default_locales: POSIX C en_US fr_FR de_DE
     -> default_timezone: UTC
     -> distrib: debian
     -> filesystem_type: ext4
     -> hostname: kameleon-debian
     -> image_disk: /home/mercierm/build/my_debian8/base_my_debian8
     -> image_format: qcow2
     -> image_size: 10G
     -> in_context: {"cmd"=>"ssh -F /home/mercierm/build/my_debian8/ssh_config my_debian8 -t /bin/bash", "proxy_cache"=>"10.0.2.2", "workdir"=>"/root/kameleon_workdir", "interactive_cmd"=>"ssh -F /home/mercierm/build/my_debian8/ssh_config my_debian8 -t /bin/bash"}
     -> include_steps: ["debian/jessie", "debian"]
     -> kameleon_cwd: /home/mercierm/build/my_debian8
     -> kameleon_recipe_dir: /home/mercierm/my_recipes
     -> kameleon_recipe_name: my_debian8
     -> kameleon_short_uuid: a0e82b372751
     -> kameleon_uuid: 84e0d71f-65d1-40a6-ab08-a0e82b372751
     -> kernel_arch: amd64
     -> kernel_args: quiet net.ifnames=0 biosdevname=0
     -> out_context: {"cmd"=>"ssh -F /home/mercierm/build/my_debian8/ssh_config my_debian8 -t /bin/bash", "proxy_cache"=>"10.0.2.2", "workdir"=>"/root/kameleon_workdir", "interactive_cmd"=>"ssh -F /home/mercierm/build/my_debian8/ssh_config my_debian8 -t /bin/bash"}
     -> proxy_in: 
     -> proxy_local: 
     -> proxy_out: 
     -> qemu_arch: x86_64
     -> qemu_cpu: 2
     -> qemu_enable_kvm: $(egrep '(vmx|svm)' /proc/cpuinfo > /dev/null && echo true)
     -> qemu_memory_size: 768
     -> qemu_monitor_socket: /home/mercierm/build/my_debian8/qemu_monitor.socket
     -> qemu_pidfile: /home/mercierm/build/my_debian8/qemu.pid
     -> release: jessie
     -> release_number: 8
     -> root_password: kameleon
     -> rootfs: /home/mercierm/build/my_debian8/rootfs
     -> rootfs_archive_download_path: /home/mercierm/build/my_debian8/rootfs.tar.xz
     -> rootfs_archive_url: http://kameleon.imag.fr/rootfs/x86_64/debian8.tar.xz
     -> setup_packages: sudo vim bash-completion curl resolvconf bzip2 bsdutils ca-certificates locales man-db less libui-dialog-perl dialog isc-dhcp-client ifupdown iptables iputils-ping iproute2 netbase net-tools psmisc openssh-server acpid acpi-support-base sysvinit systemd systemd-sysv pciutils
     -> ssh_config_file: /home/mercierm/build/my_debian8/ssh_config
     -> user_groups: sudo
     -> user_name: kameleon
     -> user_password: kameleon

You can also use the ``--dryrun`` option to list all steps that will be
executed.

.. note:: Don't hesitate to use the ``help`` option for each command to see
   the available options. For example: ``kameleon help info``

Customize variables
~~~~~~~~~~~~~~~~~~~

In this example, we will customize the default settings using the Kameleon
variables.

We will use the ``my_debian8.yaml`` recipe that we created in the previous
section.  Kameleon use variables prefixed by ``$$`` and embrace with ``{}``
like ``$${my_variable}``. Among other things, the info command allows you to
see all the defined variables in your recipe:

.. code-block:: bash

  kameleon info my_debian8.yaml
  ...
  [global]
   ...
   -> default_keyboard_layout: us,fr,de
   -> default_lang: en_US.UTF-8
   -> default_locales: POSIX C en_US fr_FR de_DE
   -> default_timezone: UTC

These variables are used by the parent recipes to set your image default
language, timezone, and keyboard. If your are french (like me ;)) you can
change the those directly in your recipe by adding these variables in the
global section. Edit your recipe like this:

.. code-block:: yaml

  global:
    default_keyboard_layout: fr
    default_lang: fr_FR.UTF-8
    default_timezone: Europe/Paris

You can also override variable using the ``--global`` option:

.. code-block:: bash

  kameleon build my_debian8.yaml --global default_timezone:UTC+2 default_lang:en_US.UTF-8
  ...
  CLI Global variable override: default_timezone => UTC+2
  CLI Global variable override: default_lang => en_US.UTF-8
  ...




Build my new recipe
~~~~~~~~~~~~~~~~~~~

There is no magic in Kameleon, everything is written in YAML, from your system
bootstrap to its export. It empowers you to customize anything you want at
anytime during the appliance build. But before changing anything, just build the
template to see how it works:

.. code-block:: bash

  kameleon build my_debian8.yaml --enable-cache

.. note::
  We enable caching all network data that will be used to build the appliance.
  Thanks to this, the recipe reconstructability is ensured (see
  :ref:`persistent_cache`)

This build operation will:

- download a base image
- create an empty virtual disk and import the downloaded image on it
- start a virtual machine (VM) on this disk
- connect to the VM
- execute the setup steps (more on this later)
- finally it will shutdown the VM and export your image on any desired format

Oops! Maybe you get an error like this one:

.. code-block:: yaml

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
the missing package:

.. code-block:: bash

    (local_context) mercierm@localhost: ~/build/my_debian7 $ sudo apt-get install socat

Press ``Ctrl-d`` or type ``exit`` to go back to the Kameleon prompt then press
``c`` and ``Enter`` to continue the build.

When Kameleon ends, a directory called ``build`` will be generated in the
current directory. You will have a debian wheezy appliance that you can try out
by executing:

.. code-block:: bash

    qemu-system-x86_64 -enable-kvm -m 1024 build/my_debian8/my_debian8.qcow2

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

Then you should add this step to the recipe at the end of the setup section:

.. code-block:: yaml

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
