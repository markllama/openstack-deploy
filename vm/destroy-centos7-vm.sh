#!/bin/bash

: ${VM_NAME=rdo-queens}
sudo virsh destroy ${VM_NAME}
sudo virsh undefine ${VM_NAME}
sudo virsh vol-delete /home/libvirt/images/${VM_NAME}.qcow2
