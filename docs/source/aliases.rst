.. _`aliases`:

-------
Aliases
-------

The aliases can be used anywhere instead of a Kameleon command. Some aliases
are provided with the templates in the ``aliases/defaults.yaml`` files within
your workspace. You can add your own aliases in this file.

An alias is define by his name as a key and a list of commands as a value. You
can call an alias with any number of arguments given in a list.

The alias access to this arguments using the ``@arg_index`` notation. The
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
