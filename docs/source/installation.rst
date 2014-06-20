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

+-------------------------------+------------------------+--------------------------------------------+----------------------------------+
|                               |        Platform        |                  Download                  |               MD5                |
+-------------------------------+------------------------+--------------------------------------------+----------------------------------+
| .. image:: _static/debian.png | **Debian 7 64bit**     | `kameleon_2.1.3-omnibus-1_amd64.deb`_      | dc69d6386b1acb5b9434e8c186ad962c |
|   :align: center              |                        |                                            |                                  |
+-------------------------------+------------------------+--------------------------------------------+----------------------------------+
| .. image:: _static/ubuntu.png | **Ubuntu 12.04 64bit** | `kameleon_2.1.3-omnibus-1_amd64.deb`_      | dc69d6386b1acb5b9434e8c186ad962c |
|   :align: center              |                        |                                            |                                  |
+-------------------------------+------------------------+--------------------------------------------+----------------------------------+
| .. image:: _static/centos.png | **CentOS 6.5 64bit**   | `kameleon-2.1.3_omnibus-1.el6.x86_64.rpm`_ | 7bc5cee07249f5d4c316e5ea885a2949 |
|   :align: center              |                        |                                            |                                  |
+-------------------------------+------------------------+--------------------------------------------+----------------------------------+


.. _`kameleon_2.1.3-omnibus-1_amd64.deb`: http://kameleon.imag.fr/pkg/kameleon_2.1.3-omnibus-1_amd64.deb
.. _`kameleon-2.1.3_omnibus-1.el6.x86_64.rpm`: http://kameleon.imag.fr/pkg/kameleon-2.1.3_omnibus-1.el6.x86_64.rpm
