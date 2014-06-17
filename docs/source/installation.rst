.. _`installation`:

------------
Installation
------------

Gem package
-----------

To install the latest release from `RubyGems`_:

.. _RubyGems: https://rubygems.org/gems/kameleon-builder

::

    gem install kameleon-builder

Or from source::

    git clone https://github.com/oar-team/kameleon.git && cd kameleon
    gem build kameleon-builder.gemspec
    gem install kameleon-builder-*.gem

On debian based distribution be sure to install the ``ruby-dev`` package first


Dist packages
-------------

These packages contain Kameleon and all its dependencies (Ruby, polipo and all
gems with their native extensions already compiled). These packages are made
with `omnibus project`_.

.. _`omnibus project`: https://github.com/opscode/omnibus-ruby

+-------------------------------+------------------------+-------------------------------+----------------------------------+
|            Platform                                    |             Download          |               MD5                |
+-------------------------------+------------------------+-------------------------------+----------------------------------+
| .. image:: _static/debian.png | **Debian 7 64bit**     | `2.1.2-omnibus`_              | ee019958da40903fe691890c55a76d64 |
|   :align: center              |                        |                               |                                  |
+-------------------------------+------------------------+-------------------------------+----------------------------------+
| .. image:: _static/ubuntu.png | **Ubuntu 12.04 64bit** | `2.1.2-omnibus`_              | ee019958da40903fe691890c55a76d64 |
|   :align: center              |                        |                               |                                  |
+-------------------------------+------------------------+-------------------------------+----------------------------------+


.. _`2.1.2-omnibus`: http://kameleon.imag.fr/pkg/kameleon_2.1.2-omnibus-1_amd64.deb
