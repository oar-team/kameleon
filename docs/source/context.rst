.. _`context`:

-------
Context
-------

To understand how Kameleon works you have to get the *context* notion. A context
is an execution environnement with its variables (like $PATH, $TERM,...), its
tools (debootstrap, yum, ...) and all its specifics (filesystem, local/remote,
...).

It also manage the connections to your context and make it easy and reliable.
When you build an appliance you deal with 3 contexts:

- The *local* context which is the Kameleon execution environnement
- The *out* context where you will bootstrap the appliance
- The *in* context which is inside the newly created appliance

These context are setup using the two globals variables: ``out_context``
and ``in_context``. They both takes 3 arguments:

cmd
    The command used to access the context.
workdir (optional)
    The working directory to tell to Kameleon where to execute the command
exec_prefix (optional)
    The command to execute before every Kameleon command in this context

For example, you are building an appliance on your laptop and you run Kameleon
in a bash shell with this configuration:

.. code-block:: yaml

    out_context:
        cmd: /bin/bash
        workdir: $$kameleon_cwd

    in_context:
        cmd: ssh my_user@localhost -p 2222 /bin/bash
        workdir: /root/kameleon_workdir
        exec_prefix: sudo

Your *local* context is this shell where you launch Kameleon on your laptop,
the *out* is a child bash of this context, and the *in* is inside the new
environnement accessed by the chroot. As you can see the local and the out
context are often very similar but sometimes it could be useful for the out
context to be elsewhere (in a VM for example).
