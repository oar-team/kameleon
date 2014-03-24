------------
Installation
------------
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
