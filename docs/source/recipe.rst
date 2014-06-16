------
Recipe
------

Kameleon reads YAML files, named  *recipes*, that describes how you will
build your appliance. These files are stored in the root of your :ref:`workspace`.
A recipe is a hierarchical structure of `Section`_, `Step`_, `Microstep`_ and
:ref:`commands`. Here is an overview of this structure:

.. code-block:: yaml

    recipe
    |
    `-- section
        |
        `-- step
            |
            `-- microstep
                |
                `-- command

The recipe also contains set of `Global variables`_ declaration and some
imports like :ref:`aliases` and :ref:`checkpoint`.

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
    It is dedicated to install and configuration steps.

export
    Export the generated appliance in the format of your choice.


.. _`step`:
.. _`microstep`:

Step and microstep
-------------------

Each *step* contains a list of *microsteps* that contains a list of :ref:`commands`
written in one YAML file.  To be found by Kameleon this file must be named by
with the step name plus the YAML extension ``.yaml``. For example the
``software_install.yaml`` step file looks like this:

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
    - extra_packages:
      - exec_in: apt-get -y --force-yes install $$packages


A step will be called like a function in the recipe. You should provide a set
of local variables if needed by the step or to override default variables (see
Variables_). Optionally, you can select only some microsteps to execute. Here
is an example of step call:

.. code-block:: yaml

    - software_install:
        - update_repositories
        - add_contribs_source
        - clean
        - extra_packages
        - packages: "debian-keyring ntp zip unzip rsync sudo"

Steps path
~~~~~~~~~~

The steps are YAML formated files stored in the ``recipe/steps`` directory of
the :ref:`workspace`. To enable a better recipe reuse and ease of write the steps
are stored by default in specific folders depending on the sections.

Kameleon is looking for the steps files using the ``include_steps`` list value,
if it is set in the recipe (NOT mandatory). These includes are often the
distribution steps. For example if you are building an ubuntu based
distribution you can use:

.. code-block:: yaml

    include_steps:
        - ubuntu
        - debian/wheezy
        - debian

It also search uppermost within the current section folder. For the previous
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
key/value syntax ``my_var: my_value``.To access these variables you have to use
the two dollars (``$$``) prefix.  Like in a Shell you can also use
``$${var_name}`` to include your variables in string like this
``my-$${variable_name}-templated``. It's also possible to use nested variables
like:

.. code-block:: yaml

    my_var: foo
    my_nested_var: $${my_var}-bar

Be careful, in YAML you cannot mix dictionary and list on the same level.
That's why, in the global dictionary, you can define your variables like in the
example above but, in the recipe or the steps, you must prefix your variable
with a ``-`` like this ``- my_var: foo``.


Global variables
~~~~~~~~~~~~~~~~~

Global variables are defined in the ``global`` dictionary of the recipe.
Kameleon use some global variable to enable the appliance build. See :ref:`context`
and `Steps path`_ for more details


Step local variables
~~~~~~~~~~~~~~~~~~~~

In the recipe, you can provide some variables when you call a step. This
variable override the global and the default variables.


Step default variables
~~~~~~~~~~~~~~~~~~~~~~

In the step file, you can define some default variables for your microsteps. Be
careful, to avoid some mistakes, these variables can be override by the step
local variables but not by the global ones. If this is the behavior you
expected just add a step local variable that take the global variable value
like this:

.. code-block:: yaml

    global:
        foo: bar
    setup:
        - my_step:
            - foo: $$foo
