# Kameleon

Kameleon should be seen as a simple but powerfull tool to generate customized
appliances. With Kameleon, you make your recipe that describes how to create
step by step your own distribution. At start kameleon is used to create custom
kvm, VirtualBox, iso images, ... but as it is designed to be very generic you
can probably do a lot more than that.

## Installation

    $ gem install kameleon

or from source

    $ git clone git://scm.gforge.inria.fr/kameleon/kameleon.git
    $ cd kameleon
    $ gem build kameleon.gemspec
    $ gem install kameleon-<version>.gem

## Usage

Just type:
    $ kameleon

## Quick start

First, get a simple example recipe in the current directory (use -w
to set a diferent workspace).

  $ kameleon new <my_test_recipe>

Then build your new recipe

  $ kameleon build <my_test_recipe>

A build directory was created and contains your new image!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
