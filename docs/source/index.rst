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

Kameleon is a simple but powerful tool to generate customized software
appliances. A software appliances is a complete operating system image
with your tools and libraries indside. With Kameleon, you can make a recipe
that describes how to create step by step your own OS distribution, or you
can extend a template to only add a few packages to a standard Linux
distribution. Kameleon can then generate an image in any format from the
same recipe build: Docker, VirtualBox, KVM, Grid'5000,...  Kameleon is made
to improve reproducibility in computer science and engineering by giving
you tool that achieve complete *reconstructability* of your appliances with
ease using cache, checkpointing and interactive breakpoint.

Have a look to the :doc:`getting_started` to start using Kameleon.

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
    grid5000_tutorial.rst
    grid5000_admin_tutorial.rst

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
