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

    apt-get install ruby-dev ruby-childprocess polipo
    gem install --no-ri --no-rdoc kameleon-builder

Centos/Fedora
-------------

::

    yum install rubygem-childprocess polipo
    gem install --no-ri --no-rdoc kameleon-builder


Archlinux
---------

::

    pacman -S ruby polipo
    gem install --no-ri --no-rdoc kameleon-builder


From Source
-----------

::

    git clone https://github.com/oar-team/kameleon.git && cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-*.gem
