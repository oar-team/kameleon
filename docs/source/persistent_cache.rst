.. _`persistent_cache`:

----------------
Persistent Cache
----------------

In order to exactly reconstruct a software appliance with the same exact version
of packages. Kameleon offer the option of creating a persistent cache that will
catch all the software packages during the building of the software appliance.
Enabling other to reconstruct the same exact software appliance with the right
package versions. Kameleon uses Polipo [1]_ which is a tiny and lightweight web proxy
to cache most of the packages that comes form the network.
First of all, you have to install Polipo on your system.
If you are under a debian distribution you can install it using the package manager::

   sudo apt-get install polipo

You can as well build it from sources and then specify the path of the generated binary using
the option ``--proxy_path``. To use, you just have to add the option ``--cache`` as an argument of the build command.
For example::

  kameleon build debian_test -b /tamp/kameleon/ --cache

This will create a tar file in the build directory ``/tmp/kameleon`` called ``debian_test-cache.tar``.
In order to use this generated cache file in another build, we have just to use the options ``--from_cache`` as follows::

   kameleon build debian_test -b /tmp/kameleon/ --from_cache /tmp/debian_test-cache.tar


.. [1] http://www.pps.univ-paris-diderot.fr/~jch/software/polipo/
