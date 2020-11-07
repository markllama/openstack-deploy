#!/bin/bash

#
# These elements must be installed before you can run the Ansible host setup
#

sudo tee /etc/sudoers.d/mark <<EOF
mark ALL=(ALL) NOPASSWD: ALL
EOF

sudo yum -y install git ansible

ansible-galaxy collection install community.libvirt
ansible-galaxy collection install community.general
