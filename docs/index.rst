========================
 Kameleon documentation
========================

.. section-numbering::
.. contents:: Table of Contents

-------------------------------------------------------------------------------

How it works
============

Kameleon should be seen as a simple but powerful tool to generate customized
appliances. With Kameleon, you make your recipe that describes how to create
step by step your own distribution. At start Kameleon is used to create custom
kvm, LXC, VirtualBox, iso images, ..., but as it is designed to be very generic
you can probably do a lot more than that.


Kameleon recipe
---------------
Kameleon compute YAML files, named  *recipes*, that describes how you will
build your appliance. These files are stored in the root of your `Workspace`_.
A recipe is a hierarchical structure of `Sections`_, `Steps`_, `Microsteps`_ and
`Commands`_. Here is an overview of this structure:
::
    recipe
    |
    \__ section
        |
        \__step
           |
           \__microstep
              |
              \__command

The recipe also contains set of `Global variables`_ declaration and some
imports like `Aliases`_ and `Checkpoint`_.

This is an example of a dummy recipe: 
::
    #===============================================================================
    # vim: softtabstop=2 shiftwidth=2 expandtab fenc=utf-8 cc=81 tw=80
    #===============================================================================
    #
    # RECIPE: dummy_recipe.yaml
    #
    # DESCRIPTION: This is the recipe description
    #
    # WARNING: This is a warning!!!
    #
    #===============================================================================
    ---
    # This is a comment
    global:
      # This is another comment
      distrib: dummy_distro
      debian_version_name: distrib_repository
      out_context:
        cmd: bash
        workdir: /
      in_context:
        cmd: chroot $$kameleon_workdir
        workdir: /
      variables: test
      extra_packages: vim

    bootstrap:
      - dummy_bootstrap_static:
        - distrib_version_name: wheeeeeeze
        # Comment
        - distrib_repository: http://myrepo.com/test

    setup:
      - dummy_software_install:
        - extra_packages: "titi toto tata"
        # Comment
        - install_cmd: 12345.213
        - dummy_step1
        # Comment
        - dummy_step2
      - dummy_root_passwd

        # Comment

    export:
      - dummy_save_appliance:
        - save_as_raw
        # Comment
        - save_as_vmdk
        # Comment
        # Comment

Sections
--------
Each section is a list of `Steps`_. Currently, there is 3 sections:

bootstrap
    This section contains the bootstrap of the new system and create the *in*
    context (see `Contexts`_).

setup
    This one is dedicated to the install and configuration steps.

export
    Export the generated appliance in the format of your choice.

Steps
-----
Each *step* contains a list of microsteps that contains a list of Commands_
written in one YAML file.  To be found by Kameleon this file must be named by
with the step name plus the YAML extension ``.yaml``. For example the
``software_install.yaml`` step file looks like this:
::

    # Software Install
    - add_contribs_source:
      - exec_in: perl -pi -e "s/main$/main contrib non-free/" /etc/apt/sources.list
    - update_repositories:
      - exec_in: apt-get -y --force-yes update
    - upgrade_system:
      - exec_in: apt-get -y --force-yes dist-upgrade
    - clean:
      - on_export_init:
        - exec_in: apt-get -y --force-yes autoclean
        - exec_in: apt-get -y --force-yes clean
        - exec_in: apt-get -y --force-yes autoremove
    # default packages
    - packages: "ntp sudo"
    - extra_packages:
      - exec_in: apt-get -y --force-yes install $$packages


A step will be called like a function in the recipe. You should provide a set
of local variables if needed by the step or to override default variables (see
Variables_). Optionally, you can select only some microsteps to execute. Here
is an example of step call:
::

    - software_install:
        - update_repositories
        - add_contribs_source
        - clean
        - extra_packages
        - packages: "debian-keyring ntp zip unzip rsync sudo"

Steps path
~~~~~~~~~~
The steps are YAML formated files stored in the ``recipe/steps`` directory of
the Workspace_. To enable a better recipe reuse and ease of write the steps
are stored by default in specific folders depending on the sections.

Kameleon is looking for the steps files using the ``include_steps`` list value,
if it is set in the recipe (NOT mandatory). These includes are often the
distribution steps. For example if you are building an ubuntu based
distribution you can use:
::

    include_steps:
        - ubuntu
        - debian/wheezy
        - debian

It also search uppermost within the current section folder. For the previous
example, in the bootstrap section, the search paths are scanned in this
order: 
::
    steps/bootstrap/ubuntu
    steps/ubuntu
    steps/bootstrap/debian/wheezy
    steps/debian/wheezy
    steps/bootstrap/debian
    steps/debian
    steps/bootstrap/
    steps/

Variables
---------
Kameleon is using preprocessed variables. You can define it with the YAML
key/value syntax ``my_var: my_value``.To access these variables you have to use
the two dollars (``$$``) prefix.  Like in a Shell you can also use
``$${var_name}`` to include your variables in string like this
``my-$${variable_name}-templated``. It's also possible to use nested variables
like: 
::

    my_var: foo
    my_nested_var: $${my_var}-bar

Be careful, in YAML you cannot mix dictionary and list on the same level.
That's why, in the global dictionary, you can define your variables like in the
example above but, in the recipe or the steps, you must prefix your variable with
a ``-`` like this ``- my_var: foo``.


Global variables
~~~~~~~~~~~~~~~~~
Global variables are defined in the ``global`` dictionary of the recipe.
Kameleon use some global variable to enable the appliance build. See Context_
and `Steps path`_ for more details

Step local variables
~~~~~~~~~~~~~~~~~~~~
In the recipe, you can provide some variables when you call a step. This
variable override the global and the default variables.

Step default variables
~~~~~~~~~~~~~~~~~~~~~~
In the step file, you can define some default variables for your microsteps. Be careful, to avoid some mistakes, these variables can be override by the step local variables but not by the global ones. If this is the behavior you expected just add a step local variable that take the global variable value like this: 
::
    global:
        foo: bar
    setup:
        - my_step:
            - foo: $$foo

Contexts
--------
To understand how Kameleon work you have to get the *context* notion. A context
is an execution environnement with his variables (like $PATH, $TERM,...), his
tools (debootstrap, yum, ...) and all his specifics (filesystem, local/remote,
...). When you build an appliance you deal with 3 contexts:
- The *local* context which is the Kameleon execution environnement
- The *out* context where you will bootstrap the appliance
- The *in* context which is inside the newly created appliance

These context are setup using the two globals variables: ``out_context``
and ``in_context``. They both takes 3 arguments:

cmd
    The command to initialize the context
workdir (optional)
    The working directory to tell to Kameleon where to execute the command
exec_prefix (optional)
    The command to execute before every Kameleon command in this context

For example, you are building an appliance on your laptop and you run Kameleon
in a bash shell with this configuration: 
::
    out_context:
        cmd: bash
        workdir: $$kameleon_cwd
    in_context:
        cmd: env -i USER=root HOME=/root PATH=/usr/bin:/usr/sbin:/bin:/sbin LC_ALL=POSIX chroot $$rootfs bash
        workdir: /


Your *local* context is this shell where you launch Kameleon on your laptop,
the *out* is a child bash of this context, and the *in* is inside the new
environnement accessed by the chroot. As you can see the local and the out
context are often very similar but sometimes it could be useful for the out
context to be elsewhere (in a VM for example).

Commands
--------
Each command is a {key => value} pair. The key is the Kameleon command name, and
the value is the argument for this command.

Exec command
~~~~~~~~~~~~
The exec command is a simple command execute, in the given context, the user
command in argument. The context is specified by the name suffix local, out or
in like this ``exec_[in/out/local]``. It is currently used most to execute bash
script, but you can use any tools callable with bash. For example this command
save the message "Hello world:" in the hello.txt file within the workdir of the
*in* context:
::
    - exec_in: echo "Hello world!" > hello.txt

Pipe command
~~~~~~~~~~~~
The ``pipe`` command allow to transfert any content from one context to
another. It takes exec command in arguments. The transfert is done by sending
the STDOUT of the first command to the STDIN of the second.
For example, this pipe command copy my_file located in the out context workdir
to the new_file within the out context workdir: 
::
    - pipe:
            - exec_out: cat my_file
            - exec_in: cat > new_file
            
This command are usually not used directly but with Aliases_.

Hook commands
~~~~~~~~~~~~~
The hook commands are design to defer some initialization or clean actions. It 
takes a list of exec and pipe command in arguments. They
are named like this ``on_[section]_init`` and ``on_[section]_clean``. The section
inside the command define on which section this clean will be executed. If the 
section is not specified the hook will be executed at the init or the clean of
the current step.

Workspace
---------
The workspace is a folder containing your Kameleon recipes and builds.

Checkpoints
-----------
Kameleon provide a modular Checkpoint mechanism. TODO
The killer feature of Kameleon is the possibility to implement your own
checkpoint mechanism, using for example the snapshot of your underneath
filesystem.

Aliases
-------
Alias example: 
::
    out2in:
        - exec_in: mkdir -p $(dirname @2)
        - pipe:
            - exec_out: cat @1
            - exec_in: cat > @2


Making your own recipes
=======================

Work in progress...

For now, see the quick Start guide in the README file.
