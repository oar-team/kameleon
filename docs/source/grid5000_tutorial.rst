==================
Grid'5000 Tutorial
==================

This tutorial will introduce Kameleon, a tool to build software appliances.
With Kameleon it is possible to generate appliances that can be deployed on different virtualization hypervisors or on baremetal.
It targets an important activity in Grid'5000 which is the customization of the experimental environments.

The tutorial will focous on the three following activities:

* Create and customize a software appliance locally using a virtualization technology.
* Export the previous created environment as a G5k environment.
* Carry out the same customization with a G5k reference environment.

All these activities encourages the use of code.

Kameleon basics
---------------

First of all, let's see all the syntax flavors that *Kameleon* has to offer.
From this point, we assume that *Kameleon* have been installed and it's already working
in your system, otherwise go to :ref:`installation` section.
Kameleon can be seen as a shell sequencer which will boost your shell scripts.
It is based on the execution of shell scripts but it provides some syntax sugar that makes
the work with shell scripts less painful.

Let's start with the basics


Kameleon Hello world
~~~~~~~~~~~~~~~~~~~~

Everything we want to build have to be specified by a recipe. Kameleon reads this recipe
and executes the appropriate actions. Let's create a hello world recipe using Kameleon.
Open a text editor and write the following:

.. code-block:: yaml

     setup:
     - first_step:
       - hello_microstep:
         - exec_local: echo "Hello world"
     # The end

Save the previous file as a YAML file. For instance, hello_world.yaml.

.. note::
    Be sure of respecting the YAML syntax and indentation `yaml`_.

.. _yaml: http://www.yaml.org/


Then, you run it like this::

     kameleon build hello_world.yaml

You will have some output that looks like this::

      [kameleon]: Starting recipe consistency check
      [kameleon]: Resolving variables
      [kameleon]: Calculating microstep identifiers
      [kameleon]: Creating kameleon working directory : /home/cristian/Repositories/exptools/setup_complex_exp/tests/new_version/build/hello_world
      [kameleon]: Building local context [local]
      [kameleon]: Building external context [out]
      [kameleon]: Building internal context [in]
      [kameleon]: Starting build recipe 'hello_world.yaml'
      [kameleon]: Step 1 : setup/first_step/hello_microstep
      [kameleon]:  ---> Running step
      [kameleon]: Starting process: "bash"
      [local_ctx]: The local_context has been initialized
      [local_ctx]: Hello world
      [kameleon]:
      [kameleon]: Build recipe 'hello_world.yaml' is completed !
      [kameleon]: Build total duration : 0 secs
      [kameleon]: Build directory : /home/cristian/Repositories/exptools/setup_complex_exp/tests/new_version/build/hello_world
      [kameleon]: Build recipe file : /home/cristian/Repositories/exptools/setup_complex_exp/tests/new_version/build/hello_world/kameleon_build_recipe.yaml
      [kameleon]: Log file : /home/cristian/Repositories/exptools/setup_complex_exp/tests/new_version/kameleon.log

With this simple example, we have already introduced most of the Kameleon concepts and syntax.
First, how recipes are structured using a hierarchy composed of: sections, steps, microsteps.

* Sections: correspond to the minimal actions that have to be performed in order to have a software
  stack that can be run almost anywhere. This brings to Kameleon a high degree of customizability, reuse of
  code and users have total control over when and where the
  sections have to take place. This minimal actions are: bootstrap, setup and export.

* Steps: It refers to a specific action to be done inside a section
  (e.g., software installation, network configuration, configure kernel).
  Steps can be declared in independent files that improves the degree of reusability.

* Microsteps: procedures composed of shell commands. The goal of dividing steps into microsteps is the
  possibility of activating certain actions within a step and performing a better checkpoint.

Kameleon hierarchy encourages the reuse (shareability) of code and modularity of procedures.
The minimal building block are the commands *exec_* which wraps shell commands adding
a simple error handling and interactivenes in case of a problem.
These commands are executed in a given :ref:`context`. Which could be: local, in, out.
They can be used as follows:

 .. code-block:: yaml

     setup:
       - first_step:
         - hello_microstep:
           - exec_local: echo "Hello world"
	   - exec_in: echo "Hello world"
	   - exec_out: echo "Hello world"
     # The end


Local context
     It represents the Kameleon execution environment. Normally is the user’s machine.

Out context
     It is where the appliance will be bootstraped. Some procedures have to be carried out in
     order to create the place where the software appliance is built (In context).
     One example is: the same user’s machine using chroot.
     Thus, in this context is where the setup of the chroot takes place.
     Other examples are: setting up a virtual machine, accessing an infrastructure in order to get a reservation and be able to deploy, setting
     a Docker container, etc.

In context
     It refers to inside the newly
     created appliance. It can be mapped to a chroot,
     virtual machine, physical machine, Linux container, etc.

In the last example all the contexts are executed on the user's machine.
Which is the default behavior that can be customized (it will be shown later on this tutorial).
Most of the time, users take advantage of the *In context* in order to customize a given a appliance.

We can add variables as well:

 .. code-block:: yaml

     setup:
       - first_step:
         - message: "Hello world"
         - hello_microstep:
           - exec_local: echo "Variable value $$message"


Let's apply the syntax to a real example in the next section.


Building a simple Debian based appliance
----------------------------------------

Kameleon already provides tested recipes for building different software appliances based
on different Linux flavors. We can take a look at the provided templates by typing::

     $ kameleon templates

Which will output::

    The following templates are available in /home/cristian/Repositories/kameleon_v2/templates:
    NAME                 | DESCRIPTION
    ---------------------|-------------------------------------------------------------
    archlinux            | Build an Archlinux base system system.
    archlinux-desktop    | Archlinux GNOME Desktop edition.
    debian-testing       | Debian Testing base system
    debian7              | Debian 7 (Wheezy) base system
    debian7-desktop      | Debian 7 (Wheezy) GNOME Desktop edition.
    debian7-oar-dev      | Debian 7 dev appliance with OAR-2.5 (node/server/frontend).
    fedora-rawhide       | Fedora Rawhide base system
    fedora20             | Fedora 20 base system
    fedora20-desktop     | Fedora 20 GNOME Desktop edition
    old-debian7          | [deprecated] Build a debian wheezy appliance using chroot...
    ubuntu-12.04         | Ubuntu 12.04 LTS (Precise Pangolin) base system.
    ubuntu-12.04-desktop | Ubuntu 12.04 LTS (Precise Pangolin) Desktop edition.
    ubuntu-14.04         | Ubuntu 14.04 LTS (Trusty Tahr) base system.
    ubuntu-14.04-desktop | Ubuntu 14.04 LTS (Trusty Tahr) Desktop edition.
    vagrant-debian7      | A standard Debian 7 vagrant base box


Let's import the template debian7::

    $ kameleon import debian7

This will generate the following files in the current directory::

    ├── debian7.yaml
    ├── kameleon.log
    └── steps
        ├── aliases
        |   └── defaults.yaml
	├── bootstrap
	│   ├── debian
	│   │   └── debootstrap.yaml
	│   ├── initialize_disk_qemu.yaml
	│   ├── install_bootloader.yaml
	│   ├── prepare_qemu.yaml
	│   └── start_qemu.yaml
	├── checkpoints
	│   └── qemu.yaml
	├── export
	│   └── save_appliance.yaml
	└── setup
	    ├── create_group.yaml
	    ├── create_user.yaml
	    └── debian
	        ├── configure_apt.yaml
		├── configure_kernel.yaml
		├── configure_keyboard.yaml
		├── configure_network.yaml
		├── configure_system.yaml
		├── install_software.yaml
		└── upgrade_system.yaml

     8 directories, 19 files

Here we can observe that a directory has been generated.
This directory contains all the steps needed to build the final software appliance.
These steps are organized by sections. There is a directory checkpoints that is going
to be explained later on.

Here we can notice that all the process of building is based on steps files written with Kameleon syntax.
Separating the steps in different files gives a high degree of reusability.

The recipe looks like this:

.. literalinclude:: debian7.yaml
   :lines: 69-125
   :language: yaml

The previous recipe build a debian wheezy using qemu.
It looks verbose but normally you as user you wont see it.
You will use it as a template in a way that will be explained later.
The recipe specify all the steps, configurations values that are going to be used
to build the appliance. Kameleon recipes gives many details to you, few things are hidden.
Which is good for reproducibility purposes and when reporting bugs.

If we have all the dependencies required as qemu, qemu-tools and debootstrap we can start to build the appliance
doing the following::

     $ kamelon build debian7.yaml

The process will start and in about few minutes
a directory called builds will be generated in the current directory,
you will have a qemu virtual disk with a base debian wheezy installed in it.
That you can try out by executing::

     $ sudo qemu-system-x86_64 -enable-kvm builds/debian7/debian7.qcow2



.. note::
   The previous recipe uses qemu to build the appliance,
   if you are using Kameleon from a virtual machine this probably wont work due to kvm.
   The recipe has to be changed in order to disable the kvm module.
   In this case you can opt for using the template *debian7-chroot* which uses a
   chroot environment to build the appliance. Those alternative methods however can take longer.


Customizing a software appliance
--------------------------------

Now, lets customize a given template in order to create a software appliance that have OpenMPI, Taktuk and tools necessary to compile source code.
Kameleon allows us to extend a given template. We will use this for adding the necessary software. Type the following::

     $ kameleon new debian_customized debian7

This will create the file debian_customized.yaml which contents are::

     ---
     extend: debian7

     global:
     # You can see the base template `debian7.yaml` to know the
     # variables that you can override

     bootstrap:
       - "@base"

     setup:
       - "@base"

     export:
       - "@base"

If we try to build this recipe, it will generate the exact same image as before.
But the idea here is to change it in order to install the desired software.
Therefore, we will modify the setup section like this::

     extend: debian7

     global:
     # You can see the base template `debian7.yaml` to know the
     # variables that you can override

     bootstrap:
       - "@base"

     setup:
       - "@base"
       - install_software:
         - packages: >
            g++ make taktuk openssh-server openmpi-bin openmpi-common openmpi-dev

     export:
       - "@base"


For building execute::

     $ kameleon build debian_customized.yaml

Then, you can follow the same steps as before to try it out and verify that the software was installed.
Now, let's make things a little more complicated. We will now compile and install TAU in our system.
So, for that let's create a step file that will look like this:


.. literalinclude:: tau_install.yaml
   :language: yaml

You have to put it under the directory *steps/setup/* and you can call it tau_install.
In order to use it in your recipe, modify it as follows:

 .. code-block:: yaml

     extend: debian7

     global:
     # You can see the base template `debian7.yaml` to know the
     # variables that you can override

     bootstrap:
       - "@base"

     setup:
       - "@base"
       - install_software:
         - packages: >
            g++ make taktuk openssh-server openmpi-bin openmpi-common openmpi-dev
       - tau_install
     export:
       - "@base"


And rebuild the image again, you will see that it wont start from the beginning.
It will take advantage of the checkpoint system and it will start from the last
successfull executed step.

When building there is the following error::


     [kameleon]: Step 46 : setup/tau_install/tau_install
     [kameleon]:  ---> Running step
        [in_ctx]: Unset ParaProf's cubeclasspath...
	[in_ctx]: Unset Perfdmf cubeclasspath...
	[in_ctx]: Error: Cannot access MPI include directory /usr/local/openmpi-install/include
     [kameleon]: Error occured when executing the following command :
     [kameleon]:
     [kameleon]: > exec_in: ./configure -prefix=/usr/local/tau-install -pdt=/usr/local/pdt-install/ -mpiinc=/usr/local/openmpi-install/include -mpilib=/usr/local/openmpi-install/lib
     [kameleon]: Press [r] to retry
     [kameleon]: Press [c] to continue with execution
     [kameleon]: Press [a] to abort execution
     [kameleon]: Press [l] to switch to local_context shell
     [kameleon]: Press [o] to switch to out_context shell
     [kameleon]: Press [i] to switch to in_context shell
     [kameleon]: answer ? [c/a/r/l/o/i]:

We can observe that the problem is related with the configure script that cannot access the MPI path.
It can be debugged by using the interactive shell provided by Kameleon.
The interactive shell allows us to log into a given context.
For this case we see that the error happened in the in context, so let's type i in order to enter to this context::

  [kameleon]: User choice : [i] launch in_context
     [in_ctx]: Starting interactive shell
  [kameleon]: Starting process: "LC_ALL=POSIX ssh -F /tmp/kameleon/debian_customized/ssh_config debian_customized -t /bin/bash"
  (in_context) root@cristiancomputer: / #

The commands executed by Kameleon remain in the bash history.
Therefore, It can be rexecuted manually.
For this case, we only need to change the path for the OpenMPI libraries.
As we have installed it using the packages they are avaiable under the directories:
*/usr/include/openmpi/*, */usr/lib/openmpi/* respectively.
If we try with the following parameters::

    ./configure -prefix=/usr/local/tau-install -pdt=/usr/local/pdt-install/ -mpiinc=/usr/include/openmpi/ -mpilib=/usr/lib/openmpi/

It will finish without any problem. We have found the bug, therefore we can just logout by typing *exit* and
then *abort* for stopping the execution and update the step file with the previous line.
If you carry out the building again you will see that now everything goes smoothly.
Again Kameleon will use the checkpoint system to avoid starting from scratch.


Creating a Grid'5000 environment.
---------------------------------

Now, let's use the extend and export functionalities for creating a Grid'5000 environment.
With this step we will see how code can be re-used with Kameleon.
Therefore, we can extend the recipe created before:

 .. code-block:: yaml

     ---
     extend: debian_customized

     global:
         # You can see the base template `debian7.yaml` to know the
         # variables that you can override

     bootstrap:
       - "@base"

     setup:
       - "@base"

     export:
       - save_appliance:
         - input: $$image_disk
         - output: $$kameleon_cwd/$$kameleon_recipe_name
         - save_as_tgz

       - g5k_custom:
         - kadeploy_file:
           - write_local:
             - $$kameleon_cwd/$$kameleon_recipe_name.yaml
             - |
               #
               # Kameleon generated based on kadeploy description file
               #
               ---
               name: $$kameleon_recipe_name

               version: 1

               os: linux

               image:
                 file: $$kameleon_recipe_name.tar.gz
                 kind: tar
                 compression: gzip

               postinstalls:
                 - archive: server:///grid5000/postinstalls/debian-x64-base-2.5-post.tgz
                   compression: gzip
                   script: traitement.ash /rambin

               boot:
                 kernel: /vmlinuz
                 initrd: /initrd.img

               filesystem: $$filesystem_type

This recipe will generate in the build directory a tar.gz image and a configuration file for Kadeploy.
For example::

     $ ls builds
     total 8831536
     -rw-r--r-- 1 root root 18767806464 juin  15 23:04 base_debian_g5k.qcow2
     -rw-r--r-- 1 root root   206403737 juin  15 23:04 debian_g5k.tar.gz
     -rw-r--r-- 1 root root         379 juin  15 23:04 debian_g5k.yaml
     -rw-r--r-- 1 root root         426 juin  15 23:03 fstab.orig
     -rw------- 1 root root         672 juin  15 23:01 insecure_ssh_key

We have to copy them in a Grid'5000 site for instance (Grenoble) by doing::

     $ scp debian_g5k.tar.gz debian_g5k.yaml grenoble.g5k:~/


Therefore if we log in the respective site and then we can submit a deploy job and
deploy the image using kadeploy::


  user@fgrenoble:~$ oarsub -I t deploy
  [ADMISSION RULE] Set default walltime to 3600.
  [ADMISSION RULE] Modify resource description with type constraints
  Generate a job key...
  OAR_JOB_ID=1663465
  Interactive mode : waiting...
  Starting...

  Connect to OAR job 1663465 via the node fgrenoble.grenoble.grid5000.fr

  user@fgrenoble:~$ kadeploy -a debian_g5k.yaml -f $OAR_NODEFILE


With luck the image will be deployed on baremetal after some few minutes.



Playing with Kameleon contexts
------------------------------

The environment that has just been deployed is a basic debian.
It doesn't have the modules required for infiniband and
other configuration that site administrators do for a specific hardware
or politics of the site.
In this case would be good to be able to use the environments already
provided by Grid'5000. This can be done by using Kameleon contexts.
The idea is to re-utilize the same recipe we have written before.

Kameleon already provides a recipe for interacting with Grid'5000 where
the configuration of the contexts is as follows:

* Local context: it is the user's machine.

* Context out: it is the site frontend.
  It is used for submitting a job and deploying
  a given Grid'5000 environment.

* Context in: will be inside the deployed node.


First, we import the G5k recipe::

  $ kameleon import debian7-g5k

And we can just make a copy of our previous recipe (debian customized) and
we name it for instance debian_customized_g5k.yaml.
This recipe will look like this:

.. literalinclude:: debian_customized_g5k.yaml
   :language: yaml

.. note:: Dont forget to put your Grid'5000 user name and site.

But there will be a problem with the installation of TAU. Because
we download the tarball directly from its web site which is an
operation not allowed in Grid'5000. Just certain sites are accessible
using a web proxy.
To solve this we have to modify the step *tau_install* like this:

.. literalinclude:: tau_install_g5k.yaml
   :language: yaml

Here, we change the context for performing the operation of download.
For now on, it will be the local context that is going to download the
tarballs. Then, we have to put them into the *in contex*, and to do so we use a pipe.
Pipes are a means to communicate contexts. We use a pipe between our local context and the in contex.

With those changes we will be able to build a G5k environment with
our already tested configuration. The recipe saves
the environment on the Kameleon workdir on the frontend.
Thus the environment is accessible to be deployed the number of times needed.


Atlas example on Grid'5000
--------------------------

Here, a more complicated example, where we install the benchmark HPL which
is used to benchmark and rank supercomputers for the TOP500 list:

.. literalinclude:: atlas_debian_g5k.yaml
   :language: yaml

We have to add to the *steps/setup* directory the following files *install_atlas.yaml* and *install_hpl.yaml* for installing atlas and hpl respectively.
Also, the `hpl makefile`_ has to be download and the path be specified on the recipe.

.. _hpl makefile: http://kameleon.imag.fr/appliance/ATLAS/Make.Linux


ATLAS:

.. literalinclude:: install_atlas.yaml
   :language: yaml

HPL:

.. literalinclude:: install_hpl.yaml
   :language: yaml


.. note::
   The building of this appliance could take around half an hour.
