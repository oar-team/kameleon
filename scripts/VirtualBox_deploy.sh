#!/bin/bash
NAME=$1
VBOX_DISK=$2

VBoxManage createvm --name $NAME --register
VBoxManage modifyvm $NAME --memory 512
VBoxManage storagectl $NAME --name SATA --add sata --controller IntelAhci --bootable on --sataportcount 1
VBoxManage storageattach $NAME --storagectl SATA --port 0 --device 0 --type hdd --medium $VBOX_DISK
#VBoxManage modifyvm $NAME --nic1 hostonly
#VBoxManage modifyvm $NAME --nic1 nat
VBoxManage startvm $NAME
#VBoxManage unregistervm $NAME --delete
