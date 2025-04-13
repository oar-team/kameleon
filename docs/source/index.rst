.. Kameleon documentation master file, created by
   sphinx-quickstart on Thu Feb 13 19:01:14 2014.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Kameleon documentation
======================

.. image:: _static/kameleon-long.png
     :align: right

-----
About
-----

Kameleon is a simple but powerful tool to generate customized operating system
images, based on traceable recipes.

Thanks to Kameleon, one can write recipes that describe how to create, step by
step, customized operating systems in any desired target format, and then cook
them (build them), just like GNU make cooks sources using a Makefile to build
binary programs.

For instance, Kameleon can create custom operating system images for QEMU/KVM,
VirtualBox, docker, LXC or bootable ISO. It can support creating such images
for any machine architecture (x86, ARM64, PPC64, ... ).

In fact, since the Kameleon engine by itself is very generic by design, a lot
more can be done, because most of the specialization happens in the recipes,
written in Kameleon's powerful recipe language (YAML based DSL).

Kameleon was initially developed to improve reproducibility in computer science
and engineering, providing a tool that achieves complete *reconstructability*
of system images with cache, checkpointing and interactive breakpoint
mechanisms.

Have a look to the :doc:`getting_started` to start using Kameleon.

-------------------
Kameleon in science
-------------------

One of Kameleon's initial goals is to foster Reproducible Research in Computer Science.

If you take benefits of using Kameleon in you research work, please cite the latest publication
about Kameleon, available in the HAL open archive at the following URL:

https://hal.inria.fr/hal-01334135

-------
Recipes
-------

Kameleon's default recipes are provided at the following URL:

https://github.com/oar-team/kameleon-recipes

Also, since Kameleon is the Operating System image builder of Grid'5000, many additional recipes can be found at the following URL:

https://github.com/grid5000/environments-recipes

And the related documentations in the Grid'5000 web site at:

https://www.grid5000.fr/w/Environment_creation

---------------
Other resources
---------------

The following repository and wiki is available for users to share recipes:

https://github.com/oar-team/kameleon-contrib

https://github.com/oar-team/kameleon-contrib/wiki

------------
Report a bug
------------

To report a bug please use this bug trackers:

For the engine:
    https://github.com/oar-team/kameleon/issues

For the recipes and templates:
    https://github.com/oar-team/kameleon-recipes/issues


------------------
User Documentation
------------------

.. toctree::
    :maxdepth: 2

    installation.rst
    getting_started.rst
    use_cases.rst
    recipe.rst
    context.rst
    commands.rst
    workspace.rst
    checkpoint.rst
    persistent_cache.rst
    inheritance.rst
    aliases.rst
    faq.rst
    other.rst

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
