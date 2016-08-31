------
Recipe
------

Kameleon reads YAML files, named  *recipes*, that describes how you will build
your appliance. A recipe is a hierarchical structure of `Section`_, `Step`_,
`Microstep`_ and :ref:`commands`. Here is an overview of this structure:

.. code-block:: yaml

    recipe
    `-- section
        `-- step
            `-- microstep
                `-- command

The recipe also contains a set of `Global variables`_ declaration and some
imports such as :ref:`aliases` and :ref:`checkpoint`.

Here is an example of a recipe:

.. literalinclude:: debian7.yaml
   :language: yaml

Section
-------

Each section is a group of steps. Currently, there are 3 sections:

bootstrap
    This section contains the bootstrap of the new system and create the *in*
    context (see :ref:`context`).

setup
    Installs and configures steps.

export
    Exports the generated appliance in the desired format.


.. _`step`:
.. _`microstep`:

Step and microstep
------------------

Each step contains a list of microsteps itself containing a list of :ref:`commands` 
written in one YAML file. To be found by Kameleon,
this file must be named by the step name plus the YAML extension ``.yaml``.
For example the ``software_install.yaml`` step file looks like this:

.. code-block:: yaml

    # Software Install
    - add_contribs_source:
      - exec_in: perl -pi -e "s/main$/main contrib non-free/" /etc/apt/sources.list
    - update_repositories:
      - exec_in: apt-get -y --force-yes update
    - upgrade_system:
      - exec_in: apt-get -y --force-yes dist-upgrade
    - clean:
      - on_export_init:
        - exec_in: apt-get -y --force-yes autoclean
        - exec_in: apt-get -y --force-yes clean
        - exec_in: apt-get -y --force-yes autoremove
    # default packages
    - packages: "ntp sudo"
    - install_extra_packages:
      - exec_in: apt-get -y --force-yes install $$packages


A step will be called like a function in the recipe. You should provide a set
of local variables if needed by the step or to override default variables (see
Variables_). Optionally, you can select only some microsteps to execute. Here
is an example of step call:

.. code-block:: yaml

    - software_install:
        - packages: "debian-keyring ntp zip unzip rsync sudo"
        - add_contribs_source
        - update_repositories
        - clean
        - install_extra_packages

Steps path
~~~~~~~~~~

The steps are YAML formated files stored in the ``steps`` directory which is
located in the same directory as the recipe. To enable a better recipe reuse
and ease of write, the steps are stored by default in specific folders
depending on the sections.

Kameleon is looking for the steps files using the ``include_steps`` list value,
if it is set in the recipe (NOT mandatory). For example, if you are building an
ubuntu based distribution you can use:

.. code-block:: yaml

    include_steps:
        - ubuntu
        - debian/wheezy
        - debian

It also searches uppermost within the current section folder. In the previous
example, in the bootstrap section, the search paths are scanned in this
order:

.. code-block:: yaml

    steps/bootstrap/ubuntu
    steps/ubuntu
    steps/bootstrap/debian/wheezy
    steps/debian/wheezy
    steps/bootstrap/debian
    steps/debian
    steps/bootstrap/
    steps/


Variables
---------

Kameleon is using preprocessed variables. You can define it with the YAML
key/value syntax ``my_var: my_value``.To access these variables, you have to
use the two dollar (``$$``) prefix. Like in a Shell you can also use
``$${var_name}`` to include your variables in string like this
``my-$${variable_name}-templated``. It is also possible to use nested variables
like:

.. code-block:: yaml

    my_var: foo
    my_nested_var: $${my_var}-bar

Be careful, in YAML you cannot mix dictionary and list on the same level.
That's why, in the global dictionary, you can define your variables as
indicated in the example above but, in the recipe or the steps, you must prefix
your variable with a ``-`` like this ``- my_var: foo``.


Global variables
~~~~~~~~~~~~~~~~

Global variables are defined in the ``global`` dictionary of the recipe.
Kameleon use some global variables to enable the appliance build. See
:ref:`context` and `Steps path`_ for more details.

You can also override a variable using inheritance mechanism or CLI
``--global`` option. For Example:

.. code-block:: bash

  kameleon build --global my_package:'vim git' --global user_name:myself myrecipe.yaml

Or in your recipe:

.. code-block:: yaml

  global:
    # kameleon is too long to type!
    user_name: myself


.. versionadded:: 2.7.0

You can even overload variable (adding content to existing value) using the
same syntax as bash:

.. code-block:: bash

  kameleon build --global setup_packages:'$$setup_packages git emacs' myrecipe.yaml

Or in your recipe:

.. code-block:: yaml

  global:
    # I need these tools
    setup_packages: $$setup_packages git emacs

For more information about inheritance variable see here:
:ref:`inheritance_variables`

Step local variables
~~~~~~~~~~~~~~~~~~~~

In the recipe, you can provide some variables when you call a step. This
variable override the global and the default variables.

.. code-block:: yaml

    setup:
      - add_user:
        - name: foo
      - add_user:
        - name: bar


Step default variables
~~~~~~~~~~~~~~~~~~~~~~

In the step file, you can define some default variables for your microsteps. Be
careful, to avoid some mistakes, these variables can be overridden by the step
local variables but not by the global ones. If this is the behavior you
expected, just add a step local variable that can be assigned by the global
variable value:

.. code-block:: yaml

    global:
        foo: bar
    setup:
        - my_step:
            - foo: $$foo

Kameleon variables
~~~~~~~~~~~~~~~~~~

It is possible to access some variables created by Kameleon from the recipe.
They are used to contextualize the execution of a recipe in a given
environment.

kameleon_recipe_name
    The recipe name (eg. my_debian7)

kameleon_recipe_dir
    Directory where the recipe is located (eg. ~/recipes)

kameleon_data_dir
    Directory the is watch by the cache mechanism: Each local file that
    is used during the build should be located here. See Data_ for more
    information.

kameleon_cwd
    Current recipe of Kameleon during the build (eg. ~/recipes/build/my_debian7)

kameleon_uuid
    Unique identifier of a Kameleon build. (eg. 33fb8999-bbd3-4bc5-badd-93983b14555d)

kameleon_short_uuid
    Shorter version of the identifier (eg. 93983b14555d)

persistent_cache
    'true' if the user enabled the cache, otherwise 'false'

.. _data:

Data
----

File that are stored in ``steps/data/`` of your recipe, or of a recipe
it extends, can be access with the built-in variable
``$$kameleon_data_dir``. The advantage of this mechanism over a simple copy
from one context to an other is twofold:

* All the artefact used to produce your recipe are stored inside you
  Kameleon workspace and the persistent cache is caching everything that is
  located on these directories.
* You can override any artifacts inherited from a parent recipe by
  providing an other file that as the same name in the ``steps/data/``
  folder of the child recipe.

.. warning:: You **MUST** use this directory if you want to cache any data
   that is not coming from the web.

An example is better than long sentences, so here is an example:

By default, some Kameleon recipes gives you a ``.bashrc`` file that
customize you prompt and add some aliases, but you have your own
built-over-the-years bash configuration file and you want all your images
to have it. To do so, just override the ``skel/.bashrc`` that is used by
the ``kameleon_customization.yaml`` step in your data folder:

.. code-block:: bash

   # where your recipe is:
   mkdir -p steps/data/skel
   cp ~/.bashrc steps/data/skel

And that's it! When you will build your recipe all your aliases and pretty
prompt colors will be there :)
