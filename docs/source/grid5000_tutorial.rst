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
    Be sure of respecting the YAML syntax.

Para.

----------

Para.


.. note::
    On debian based distribution be sure to install the ``ruby-dev`` package first

To install the latest release from `RubyGems`_:

.. _RubyGems: https://rubygems.org/gems/kameleon-builder

::

    gem install kameleon-builder --pre

Or from source::

    git clone https://github.com/oar-team/kameleon.git
    cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-<version>.gem


Any troubles?
~~~~~~~~~~~~~
If you got an error message like this one::

    ``/usr/lib/ruby/1.9.1/rubygems/custom_require.rb:36:in `require': cannot load such file -- mkmf (LoadError)``

It's because you need the ``ruby-dev`` package to fit the dependancies.
