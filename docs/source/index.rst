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

Kameleon is a simple but powerful tool to generate customized appliances. With
Kameleon, you make your recipe that describes how to create step by step your
own distribution. At start Kameleon is used to create custom kvm, docker,
VirtualBox, ..., but as it is designed to be very generic you can probably do a
lot more than that.

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

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
