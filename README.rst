Kameleon appliance builder
==========================

Kameleon should be seen as a simple but powerful tool to generate customized
appliances. With Kameleon, you make your recipe that describes how to create
step by step your own distribution. At start Kameleon is used to create custom
kvm, LXC, VirtualBox, iso images, ..., but as it is designed to be very generic
you can probably do a lot more than that.

.. _`installation`:

------------
Installation
------------

To install the latest release from `RubyGems`_:

.. _RubyGems: https://rubygems.org/gems/kameleon-builder

From RubyGems
-------------

Debian/Ubuntu
-------------

::

    apt-get install ruby-childprocess
    gem install --no-ri --no-rdoc kameleon-builder

Fedora
------

::

    yum install rubygem-childprocess
    gem install --no-ri --no-rdoc kameleon-builder


From Source
-----------

::

    git clone https://github.com/oar-team/kameleon.git && cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-*.gem

-----
Usage
-----

Just type

::

    kameleon

...to see the cli help :

::

    Commands:
      kameleon build [RECIPE_PATH]                # Builds the appliance from the given recipe
      kameleon checkpoints [RECIPE_PATH]          # Lists all availables checkpoints
      kameleon clean [RECIPE_PATH]                # Cleaning 'out' and 'local' contexts and removing all checkpoints
      kameleon help [COMMAND]                     # Describe available commands or one specific command
      kameleon import [TEMPLATE_NAME]             # Imports the given template
      kameleon new [RECIPE_NAME] [TEMPLATE_NAME]  # Creates a new recipe
      kameleon templates                          # Lists all defined templates
      kameleon version                            # Prints the Kameleon's version information

    Options:
      [--color], [--no-color]  # Enable colorization in output
                               # Default: true
      [--debug], [--no-debug]  # Enable debug output

First, you should select a template. To see the available templates use:

::

    kameleon templates

Then, create a new recipe from the template you've just choose.

::

    kameleon new my_test_recipe template_name

Then build your new recipe with the build command:

::

    kameleon build my_test_recipe

A ``builds`` directory will be created and will contain your new image!

To go further, it is highly recommended you start with the `Getting Started`_ guide.


.. _Getting Started: http://kameleon.imag.fr/getting_started.html

------------
Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
