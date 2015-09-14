.. _`persistent_cache`:

----------------
Persistent Cache
----------------


In order to exactly reconstruct a software appliance with the same exact
version of packages. Kameleon offer the option of creating a persistent cache
that will catch all the software packages during the building of the software
appliance.  Enabling other to reconstruct the same exact software appliance
with the right package versions. Kameleon uses Polipo [1]_ which is a tiny and
lightweight web proxy to cache most of the packages that comes form the
network.  First of all, you have to install Polipo on your system.  If you are
under a debian distribution you can install it using the package manager::

   sudo apt-get install polipo

You can as well build it from sources and then specify the path of the
generated binary using the option ``--polipo-path``.
Before using it you have to declare the variable proxy_cache, for example

.. code-block:: yaml

    out_context:
      cmd: bash
      workdir: $$kameleon_cwd
      proxy_cache: 127.0.0.1

    # Shell session that allows us to connect to the building machine in order to
    # configure it and setup additional programs
    ssh_config_file: $$kameleon_cwd/ssh_config
    in_context:
      cmd: LC_ALL=POSIX ssh -F $$ssh_config_file $$kameleon_recipe_name -t /bin/bash
      workdir: /
      proxy_cache: 10.0.2.2


To use, you just have to
add the option ``--enable-cache`` as an argument of the build command.
For example::

  kameleon build my_recipe.yaml -b /tmp/kameleon/ --enable-cache

This will create a tar file in the build directory ``/tmp/kameleon`` called
``my_recipe-cache.tar``.  In order to use this generated cache file in
another build, we have just to use the options ``--from-cache`` as follows::

   kameleon build my_recipe.yaml -b /tmp/kameleon/ --from_cache /tmp/my_recipe-cache.tar


.. [1] http://www.pps.univ-paris-diderot.fr/~jch/software/polipo/
