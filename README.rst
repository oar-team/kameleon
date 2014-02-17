Kameleon appliance builder
==========================

Kameleon should be seen as a simple but powerful tool to generate customized
appliances. With Kameleon, you make your recipe that describes how to create
step by step your own distribution. At start Kameleon is used to create custom
kvm, LXC, VirtualBox, iso images, ..., but as it is designed to be very generic
you can probably do a lot more than that.

------------
Installation
------------

To install the latest release from `RubyGems`_:

.. _RubyGems: https://rubygems.org/gems/kameleon-builder

::

    gem install kameleon-builder --pre

Or from source:

::

    git clone https://github.com/oar-team/kameleon.git
    cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-<version>.gem


-----
Usage
-----

Just type

::

    kameleon

...to see the cli help :

::

    Commands:
      kameleon build [RECIPE_NAME]                        # Builds the appliance from the recipe
      kameleon checkpoints [RECIPE_NAME]                  # Lists all availables checkpoints
      kameleon clear [RECIPE_NAME]                        # Cleaning out context and removing all checkpoints
      kameleon help [COMMAND]                             # Describe available commands or one specific command
      kameleon new [RECIPE_NAME] -t, --template=TEMPLATE  # Creates a new recipe
      kameleon templates                                  # Lists all defined templates
      kameleon version                                    # Prints the Kameleon's version information

    Options:
          [--no-color]             # Disable colorization in output
          [--debug]                # Enable debug output
      -w, [--workspace=WORKSPACE]  # Change the kameleon current work directory. (The folder containing your
                                   # recipes folder). Default : ./

First, you should select a template. To see the available templates use:

::

    kameleon templates

Then, create a new recipe from the template you've just choose. This will
create a `recipes` folder in the current directory. (use `-w` option to set a
different workspace).

::

    kameleon new my_test_recipe -t template_name

Then build your new recipe with the build command:

::

    kameleon build my_test_recipe

A `builds` directory was created and contains your new image!

To go further, it is highly recommended you start with the :doc:`getting_started`
guide.

------------
Contributing
------------


1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
