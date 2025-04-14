Kameleon appliance builder
==========================

Kameleon is a simple but powerful tool to generate customized operating system
images, based on traceable recipes.

Thanks to Kameleon, one can write recipes that describe how to create, step by
step, customized operating systems in any desired target format, and then cook
them (build them), just like GNU make cooks sources using a Makefile to build
binary programs.

For instance, Kameleon can create custom operating system images for QEMU/KVM,
VirtualBox, docker, LXC or bootable ISO. It can support creating such images
for any machine architecture (x86, ARM64, PPC64, ... ).

In fact, since the Kameleon engine by itself is very generic by design, a lot
more can be done, because most of the specialization happens in the recipes,
written in Kameleon's powerful recipe language (YAML based DSL).

Kameleon was initially developed to improve reproducibility in computer science
and engineering, providing a tool that achieves complete *reconstructability*
of system images with cache, checkpointing and interactive breakpoint
mechanisms.

* Latest documentation: http://kameleon.imag.fr/getting_started.html
* Source code and issue tracker: https://github.com/oar-team/kameleon
