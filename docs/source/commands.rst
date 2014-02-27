.. _`commands`:

--------
Commands
--------

Each command is a {key => value} pair. The key is the Kameleon command name,
and the value is the argument for this command.

Exec
~~~~

The exec command is a simple command execute, in the given context, the user
command in argument. The context is specified by the name suffix local, out or
in like this ``exec_[in/out/local]``.

It is currently used most to execute bash script, but you can use any tools
callable with bash.

For example this command save the message "Hello world:" in the hello.txt file
within the workdir of the *in* context:

.. code-block:: yaml

    - exec_in: echo "Hello world!" > hello.txt

Pipe
~~~~

The ``pipe`` command allow to transfert any content from one context to
another. It takes exec command in arguments.

The transfert is done by sending the STDOUT of the first command to the STDIN
of the second.

For example, this pipe command copy my_file located in the out context workdir
to the new_file within the in context workdir:

.. code-block:: yaml

    - pipe:
        - exec_out: cat my_file
        - exec_in: cat > new_file

This command are usually not used directly but with :ref:`Aliases`.

Hooks
~~~~~

The hook commands are design to defer some initialization or clean actions. It
takes a list of exec and pipe command in arguments. They are named like this
``on_[section]_init`` and ``on_[section]_clean``.

The section inside the command define on which section this clean will be
executed. If the section is not specified the hook will be executed at the init
or the clean of the current step.

For example, if you want to clean the ``/tmp`` folder at the end of the setup,
you can add anywhere in a step:

.. code-block:: yaml

    - on_setup_clean:
        - exec_in: rm -rf /tmp/mytemp
