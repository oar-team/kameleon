---
FAQ
---

.. note::
  Work in progress...

Why my step file is not valid?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
When you try to build your recipe, you gat this message::

  [global]: The macrostep /path/to/my/step/step.yaml is not valid

It means your step is not a valid YAML file. Be sure that you did not use some tabulations
instead of spaces or mix dictionnary and list in the same level. It is recommended to (re)read
the :doc:`recipe` documentation.

I have some troubles with qemu-nbd, what should I do?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
qemu-nbd is heavily used is some recipes and when the recipe crash it can be left in a 
bad state. So, when you build you got this::

  qemu-nbd: Failed to bdrv_open ...
  nbd device /dev/nbd2 is unavailable
  
It means the that the ``/dev/ndb2`` device is not available anymore so go to the recipe and
change the value of ``nbd_device`` to something else like ``/dev/nbd3``.

.. note::
  This is a cleaning problem and this is just a workaround. If you find an way to be clean
  the nbd device correctly lest us know!

If the problem persist you can try to reboot your computer or remove the entire build directory.

