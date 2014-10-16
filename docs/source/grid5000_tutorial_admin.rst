========================
Grid'5000 Admin Tutorial
========================

The tutorial will focous on the three following activities:

* Create and customize a software appliance locally using a virtualization
  technology.
* Export the previous created environment as a G5k environment.
* Carry out the same customization with a G5k reference environment.

Introduction
------------

Kameleon can be seen as a shell sequencer which will boost your shell scripts.
It is based on the execution of shell scripts but it provides some syntax sugar
that makes the work with shell scripts less painful.

On peut commencer à travailler avec kameleon de deux manieres. La premiere est
d'écrire manuellement ces recettes from scrach. La deuxieme consiste à
construire ces recettes à partir de models existants. C'est cette deuxieme
partie qui nous interesse dans ce tutoriel. Nous allons voir comment créer de
nouvelles recettes et les partager.


Building a simple Debian based appliance
----------------------------------------

Tout d'abord, il nous installer kameleon. Pour cela, referer vous à la section
:ref:`installation`

Kameleon n'est livré avec aucun template par défaut::

    $ kameleon template list

Pour commencer, il faut ajouter un dépôt de recettes::

    $ kameleon template repo add default https://github.com/oar-team/kameleon-recipes.git
    $ kameleon template list

Maintenant vous devriez voir la liste des template préfixées par le nom du
dépôt, ici "default".

Pour construire une image de Debian 7 nous avons le choix entre plusieurs
moteurs de virtualiation::

    $$ kameleon template list | grep debian7

Pour ce tutoriel nous allons choisir qemu mais vous pouvez choisir virtualbox
ou encore chroot.

Let's import the template debian7::

    $ kameleon new my_debian7 default/qemu/debian7

This will generate the following files in the current directory::

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

La nouvelle recette ``my_debian7.yaml`` hérite de la recette de base
``default/qemu/debian7.yaml`` comme on peut le voir dans le fichier ``my_debian7.yaml``
avec le mot clé ``extend``

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
    extend: default/virtualbox/debian7.yaml

    global:
        # You can see the base template `default/virtualbox/debian7.yaml` to know the
        # variables that you can override

    bootstrap:
      - "@base"

    setup:
      - "@base"

    export:
      - "@base"

Cette recette fait exactement la même chose que la recette parente.


The process will start and in about few minutes
a directory called build will be generated in the current directory,
you will have a qemu virtual disk with a base debian wheezy installed in it.
That you can try out by executing::

     $ sudo qemu-system-x86_64 -enable-kvm build/debian7/debian7.qcow2

Creating a Grid'5000 environment.
---------------------------------

Now, let's use the extend and export functionalities for creating a Grid'5000 environment.
With this step we will see how code can be re-used with Kameleon.
Therefore, we can extend the recipe created before

::

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

