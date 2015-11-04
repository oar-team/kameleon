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

    apt-get install ruby-dev ruby-childprocess polipo libguestfs-tools
    gem install --no-ri --no-rdoc kameleon-builder

Centos/Fedora
-------------

::

    yum install rubygem-childprocess polipo libguestfs-tools
    gem install --no-ri --no-rdoc kameleon-builder


Archlinux
---------

::

    pacman -S ruby polipo libguestfs
    gem install --no-ri --no-rdoc kameleon-builder


From Source
-----------

::

    git clone https://github.com/oar-team/kameleon.git && cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-*.gem

Completion
----------

You can enable Bash or Zsh completion of Kameleon CLI using files in the
``completion`` folder within the source repository:

.. code-block:: bash

  # for Zsh
  cp ./completion/_kameleon /usr/share/zsh/functions/Completion/Unix/
  # for Bash
  cp ./completion/kameleon.bash /etc/bash_completion.d/


