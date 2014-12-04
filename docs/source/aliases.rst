.. _`aliases`:

-------
Aliases
-------

How it works
------------

The aliases can be used anywhere instead of a Kameleon command. Some aliases
are provided with the templates in the ``steps/aliases/defaults.yaml`` files
within your workspace.

An alias is define by its name as a key and a list of commands as a value. You
can call an alias with any number of arguments given in a list.

The alias access this arguments using the ``@arg_index`` notation. The
argument index start at 1. So, ``@1`` is the first argument ``@2`` is the
second ans so on.

A good example is the alias define to copy from the out to the in context:

.. code-block:: yaml

    # alias definition
    out2in:
        - exec_in: mkdir -p $(dirname @2)
        - pipe:
            - exec_out: cat @1
            - exec_in: cat > @2
    # alias call
    out2in:
        - ./my_file_out
        - ./copy_of_my_file_in

Custom aliases file
-------------------

.. versionadded:: 2.4.0

You can add your own aliases by adding a new aliases file in your steps in the 
``step/aliases/`` path. For example you could create an alias for installing 
packages in Debian in a file name ``my_aliases.yaml``:

.. code-block:: yaml

    # My aliases
    deb_install_in:
        - exec_in: apt-get install -y --force-yes @1

Then add the ``aliases`` section your recipe to override the template's one and 
add your own aliases file to the defaults and use it:

.. code-block:: yaml
    
    extends: default/qemu/debian7
    
    aliases:
        - defaults.yaml
        - my_aliases.yaml
    
    ...
    
    setup:
        - my_step:
            - install_python:
                -deb_install_in: python python-dev
    ...

