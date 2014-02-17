# Kameleon

Kameleon should be seen as a simple but powerful tool to generate customized
appliances. With Kameleon, you make your recipe that describes how to create
step by step your own distribution. At start Kameleon is used to create custom
kvm, LXC, VirtualBox, iso images, ..., but as it is designed to be very
generic you can probably do a lot more than that.

## Installation
Simply install it from the Gem repository (not working yet):

    gem install kameleon-builder --pre

Or from source:

    git clone https://github.com/oar-team/kameleon.git
    cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-<version>.gem

## Usage

Just type:

    kameleon

## Quick start

First, you should select a template. To see the available templates use:

    kameleon templates

Then, create a new recipe from the template you've just choose. This will
create a `recipes` folder in the current directory. (use `-w` option to set a
different workspace).

    kameleon new my_test_recipe -t template_name

Then build your new recipe with the build command:

    kameleon build my_test_recipe

A `builds` directory was created and contains your new image!

To go further, get more documentation in the docs folder.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
