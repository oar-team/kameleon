.. _`inheritance`:

-----------
Inheritance
-----------

.. versionadded:: 2.1.0

Kameleon have an inheritance mecanism of recipes. You can create a new recipe
which is based on another recipe. Thus, customize your appliances by focusing
on the specific needs of the appliance.

By default, the Kameleon command ``new`` creates a new recipe that
inherits a template recipe. The keyword ``extend`` is used to specify
the recipe upon which will be based the new recipe.

Recipe example that inherits the recipe ``debian7``:

.. code-block:: yaml

    ---
    extend: debian7

    bootstrap:
      - "@base"

    setup:
      - "@base"
      - create_user:
        - name: my_super_user
        - groups: sudo admin
        - password: my_super_password

    export:
      ## do nothing


Inheritance and section
-----------------------

To manage more deeply the recipe inheritance mecanism, we use the keyword
``@base``, to import all steps from a section of the parent recipe to our
recipe. We can then execute our customizing steps before or after the parent
steps. On the contrary, the absence of the keyword ``@base`` is used to ignore
the parent steps in the new recipe.


.. _`inheritance_variables`:

Inheritance and variables
-------------------------

All global variables are overloaded in the daughter recipe.
If the recipe contains various settings, we can use this feature to customize
the appliance according to your needs:

.. code-block:: yaml

    ---
    extend: fedora20

    global:
      user_name: my_user     ## instead of 'kameleon'
      arch: i386             ## instead of 'x64_86'
      image_size: 20G        ## instead of '10G'
      filesystem_type: ext3  ## instead of 'ext4'
      ## NEW in 2.7.0
      setup_packages: $${setup_packages} git

    bootstrap:
      - "@base"

    setup:
      - "@base"

    export:
      - "@base"

On the previous example, we get a new recipe and a new appliance,
without having to maintain the base recipe ``fedora20``.

