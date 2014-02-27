.. _`checkpoint`:

----------
Checkpoint
----------

Kameleon provide a modular Checkpoint mechanism. Indeed, Kameleon give you the
possibility to implement your own checkpoint mechanism, using for example the
snapshot feature of your underneath filesystem. To do so, you have to fill in a
YAML file, located in the ``checkpoints`` folder of your workspace, in which
you have to define 4 commands:

create
    The checkpoint first creation command

apply
    The command applies a previous checkpoint state before starting build

clear
    Remove all checkpoints

list
    List the available checkpoints

You can use the Kameleon current microstep id in your command with like this
``@microstep_id``.

The checkpoint is selected in the recipe with a key/value couple where the
value is the checkpoint yaml file name: ``checkpoint: my_checkpoint_file.yaml``

