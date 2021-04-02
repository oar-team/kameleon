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

    apt-get install ruby-dev ruby-childprocess libguestfs-tools
    gem install --no-document kameleon-builder

Centos/Fedora
-------------

::

    yum install rubygem-childprocess libguestfs-tools
    gem install --no-document kameleon-builder


Archlinux
---------

::

    # install libguestfs from AUR by yourself ;)
    pacman -S ruby
    # Be sure that your gem PATH is set correctly
    gem install --no-document kameleon-builder


From Source
-----------

::

    git clone https://github.com/oar-team/kameleon.git && cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-*.gem

Completion
----------

You can enable Bash or Zsh completion of Kameleon CLI using files in the
``completion`` folder within the source repository or directly from the
Gem:

.. code-block:: bash

  # Go to source code folder
  # for example: /var/lib/gems/2.1.0/gems/kameleon-builder-2.7.6/
  # for Zsh
  cp /completion/_kameleon /usr/share/zsh/functions/Completion/Unix/
  # for Bash
  cp ./completion/kameleon.bash /etc/bash_completion.d/


