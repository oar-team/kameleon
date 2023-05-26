.. _`commands`:

--------
Commands
--------

Each command is a {key => value} pair. The key is the Kameleon command name,
and the value is the argument for this command.

Exec
~~~~

The exec command is a simple command execution, in the given context. The 
command to run is passed in argument. The context is given by the suffix: local, out or
in, i.e ``exec_[in/out/local]``.

It can be used to execute a shell script (bash) command line.

For example this command save the message "Hello world:" in the hello.txt file
within the workdir of the *in* context:

.. code-block:: yaml

    - exec_in: echo "Hello world!" > hello.txt

Whenever an exec command fails, it will trigger a breakpoint, unless Kameleon is run in script mode (`kameleon build --script ...`).

Beware that an execution in a usual Kameleon contexts (e.g. a bash shell) only fails if the latest command of a shell sequence fails. So make sure to handle errors correctly if executing a sequence of shell commands (or use `set -e` for instance).


Pipe
~~~~

The ``pipe`` command allows one to transfer any content from one context to
another. It takes exec commands as arguments.

The transfer is done by sending the STDOUT of the first command to the STDIN
of the second one.

For example, the following pipe command copy my_file located in the out context workdir
to the new_file within the in context workdir:

.. code-block:: yaml

    - pipe:
        - exec_out: cat my_file
        - exec_in: cat > new_file

This example is usually not used directly in microsteps, but in :ref:`Aliases`.

Rescue
~~~~~~

The ``rescue`` command take an array of 2 sub-commands as arguments, so that if the first command fails, the second one is run.

Example:

.. code-block:: yaml

    - rescue:
        - exec_in: cp file2 file2
        - breakpoint: "copy failed"

Breakpoint
~~~~~~~~~~

The ``breakpoint`` command print the message passed as parameter, then interrupts the execution of the kameleon build, and offers some interactivity to enter one of the excution context, retry or abort.

Test
~~~~

The ``test`` command take an array of 3 sub-commands as arguments. The first command has to be an ``exec``, which return status determines whether the second (in case of success) or third command (if failed) should be executed. The second and third commands can be any command.

Example:

.. code-block:: yaml

    - test:
        - exec_in: grep -q "something" file
        - exec_out: echo "something was found" > file
        - exec_local: echo "something was not found!" > file

Compared to a test writen in the shell script commands passed to a ``exec`` command, the advantage of the ``test`` command is that the sub-commands can be in different contexts.

Group
~~~~~

The ``group`` command allows one to group several commands, possibly using different contexts.

Example:

.. code-block:: yaml

    - test:
        - exec_in: grep -q "something" file
        - group:
            - exec_out: echo "something was found" > file
            - exec_in: echo "something was found" > file
        - exec_out: echo "something was not found" > file

Hooks
~~~~~

The hook commands are designed to defer some initialization or clean-up actions. They
take a list of as arguments. Hook commands are named as follows:
``on_[section]_init`` and ``on_[section]_clean``.

The section inside the command name defines which section the action will be
executed in. If the section is not specified the hook will be executed in the init
or clean stage of the current step.

For example, if you want to clean the ``/tmp`` folder at the end of the setup,
you can add anywhere in a step:

.. code-block:: yaml

    - on_setup_clean:
        - exec_in: rm -rf /tmp/mytemp

NB: ``on_[section]_clean`` hooks are executed in the reverse order of their declarations: first declared in the recipe is last executed.
