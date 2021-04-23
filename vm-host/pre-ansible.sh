#!/bin/bash

#
# These elements must be installed before you can run the Ansible host setup
#

sudo tee /etc/sudoers.d/mark <<EOF
mark ALL=(ALL) NOPASSWD: ALL
EOF

if [ -f /etc/centos-release ] ; then
    sudo yum -y install epel-release
fi
sudo dnf -y install git ansible

ansible-galaxy collection install community.libvirt
ansible-galaxy collection install community.general
ansible-galaxy collection install containers.podman
