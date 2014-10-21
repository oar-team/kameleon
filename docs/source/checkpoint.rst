.. _`checkpoint`:

----------
Checkpoint
----------

.. note::
    This documentation is currently being written...

Your own checkpoint mechanism
=============================

Kameleon provides a modular checkpoint mechanism. Indeed, Kameleon give you the
possibility to implement your own checkpoint mechanism, using for example the
snapshot feature of your underneath filesystem. To do so, you have to fill in a
YAML file, located in the ``steps/checkpoints`` directory and define this
commands:

enabled?
    Indicates whether the system is ready to make list_checkpoints

create
    The checkpoint first creation command

apply
    The command applies a previous checkpoint state before starting build

clear
    Removes all checkpoints

list
    Lists the available checkpoints

You can use the Kameleon current microstep id in your command with like this
``@microstep_id``. The checkpoint is selected in the recipe with a key/value
couple where the value is the checkpoint yaml file name: ``checkpoint:
my_checkpoint_file.yaml``


The following example is a very simple checkpoint implementation:

.. code-block:: yaml

    enabled:
      - exec_local: test -f $KAMELEON_WORKDIR/list_checkpoints.txt

    create:
      - exec_local: echo @microstep_id >> $KAMELEON_WORKDIR/list_checkpoints.txt

    apply:
      - exec_local: echo "restore to @microstep_id"

    list:
      - exec_local: cat $KAMELEON_WORKDIR/list_checkpoints.txt

    clear:
      - exec_local: rm -f $KAMELEON_WORKDIR/list_checkpoints.txt
