==================
Grid'5000 Tutorial
==================

This tutorial will introduce Kameleon a tool to build software appliances that can be
deployed on different infrastructures such as: virtualization, cloud computing, baremetal, etc.

---------------
Kameleon basics
---------------

First of all, let's see all the syntax flavors that Kameleon have to offer.
From this point, we assume that kameleon have been installed and it's already working
in your system, otherwise will refer to[1].
Kameleon can be seen as a shell sequencier which will boost your shell scripts.
It is based on the execution of shell scripts but it provides some syntax sugar that makes
the work with shell scripts less painfull.

We will start with the basics

Kameleon Hello world
~~~~~~~~~~~~~~~~~~~~

Everything we want to build have to be specified by a recipe. Kameleon will read this recipe
and it will execute the appropiate actions. Let's create a hello world recipe for kameleon.
Open a text editor and write the following::

     setup:
     - first_step:
       - hello_microstep:
         - exec_local: echo "Hello world"
     # The end

save the privious file as a YAML file. For instance hello_world.yaml.

.. note::
    Be sure of respecting the YAML syntax `yaml`_.

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
First, how recipes are structured. Which could be done using: sections, steps, microsteps.

* Sections: The sections correspond to the minimal actions that have to be performed in order to have a software
  stack that can be run almost anywhere. This brings to Kameleon a high degree of customizability, reuse of
  code and users have total control in when and where the
  sections have to take place. This minimal actions are: bootstrap, setup and export.

* Steps: It refers to a specific action to be done inside a section.
  Steps can be declared in independent files that improves the degree of reusability.

* Microsteps: procedures composed of shell commands. The goal of dividing steps into microsteps is the
  possibility of activating certain actions within a step.

The Kameleon hierarchy encourages the reuse (shareability) of code and modularity of procedures.

The minimal building block are the commands exec_ which wraps shell commands adding
a simple error handling and interactivenes in case of a problem.
These commands are executed in a given context. Which could be: local, in, out.
That are going to be defined later. They can be used as follows::

     setup:
     - first_step:
       - hello_microstep:
         - exec_local: echo "Hello world"
	 - exec_in: echo "Hello world"
	 - exec_out: echo "Hello world"
     # The end


* Local context: It represents the Kameleon execution environment. Normally is the user’s machine.

* OUT context: It is where the appliance will be bootstraped. Some procedures have to be carried out in
  order create the place where the software appliance is built (In context).
  This can be: the same user’s machine using chroot.
  Thus, in this context is where the setup of the chroot takes place.
  Establishing the proper environmental variables in order to have a clean environment.
  Other examples are: setting up a virtual machine, access to an infrastructure in order to get an instance and be able to deploy, setting
  a Docker container, etc.

* IN context: It makes reference to inside the newly
  created appliance. It can be mapped to a chroot,
  virtual machine, physical machine, Linux container, etc.
