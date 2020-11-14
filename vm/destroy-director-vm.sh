#!/bin/bash

 : ${VM_NAME=osp-13}
sudo virsh destroy ${VM_NAME}
sudo virsh undefine ${VM_NAME}
sudo virsh vol-delete /home/libvirt/images/${VM_NAME}.qcow2
