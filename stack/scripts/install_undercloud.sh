#!/bin/bash
#
# Install and configure the undercloud on a host
#
set -u # Exit for undefined variables

# Credentials shouldn't be saved in a file on github
# Source them locally to fill them in for the scripts
#
: ${SM_FILE=~/rhel_credentials.sh}
if [ -r ${SM_FILE} ] && grep -q 'Red Hat' /etc/os-release ; then
    #echo "FATAL: Missing credentials file ${SM_FILE}"
    #echo "Required to install container images"
    #exit 2
    source ${SM_FILE}
fi


function main() {

    # Install the undercloud
    # check for stackrc
    # check for stack installed
    if [ ! -f ~/undercloud.conf ] ; then
        echo ERROR: no undercloud.conf is present. Exiting
        return 1
    fi
    openstack undercloud install

    source ~/stackrc
    openstack subnet set \
              --dns-nameserver 172.16.3.3 \
              --dns-nameserver 192.168.1.1 \
              ctlplane-subnet

    import_vm_images
    import_container_images

    if [ -f ~/instackenv.json ] ; then
        prepare_overcloud_nodes
    fi
}

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
function registry_ip() {
    grep -e '^local_ip = ' undercloud.conf |
        tr -d ' ' |
        cut -d= -f2 |
        cut -d/ -f1
}

function import_vm_images() {

    # pull new image packages
    sudo yum -y install rhosp-director-images rhosp-director-images-ipa

    IMAGE_TARS="/usr/share/rhosp-director-images/overcloud-full-latest-13.0.tar
    /usr/share/rhosp-director-images/ironic-python-agent-latest-13.0.tar"

    # create a place for images
    mkdir -p ~/images

    for i in $IMAGE_TARS; do
        tar -C ~/images -xvf $i
    done

    source ~/stackrc
    openstack overcloud image upload --image-path /home/stack/images/
}

function import_container_images() {
    
    source ~/stackrc
    
    openstack overcloud container image prepare \
              --namespace=registry.access.redhat.com/rhosp13 \
              --push-destination=$(registry_ip):8787 \
              --prefix=openstack- \
              --tag-from-label {version}-{release} \
              --output-env-file=/home/stack/overcloud_images.yaml \
              --output-images-file /home/stack/local_registry_image_list.yaml

    cat <<EOF >~/container_image_registry_login.yaml
ContainerImageRegistryLogin: true
ContainerImageRegistryCredentials:
  registry.access.redhat.com:
    ${SM[USERNAME]}: ${SM[PASSWORD]}
EOF

    cat ~/container_image_registry_login.yaml \
        ~/local_registry_image_list.yaml \
        > ~/local_registry_images.yaml

    sudo docker login \
         --username "${SM[USERNAME]}" \
         --password "${SM[PASSWORD]}" \
         registry.access.redhat.com

    sudo openstack overcloud container image upload \
         --config-file  ~/local_registry_images.yaml \
         --verbose
}

function prepare_overcloud_nodes() {

    if [ ! -f ~/instackenv.json ] ; then
        echo "WARN: missing overcloud node spec instackenv.json"
        return 0
    fi

    source ~/stackrc
    # load the overcloud node list/spec
    openstack overcloud node import --validate-only ~/instackenv.json
    openstack overcloud node import ~/instackenv.json

    # inspect the nodes and prepare them for overcloud installation
    openstack overcloud node introspect --all-manageable --provide
}

# -----------------------------------------------------------------------------
# Finally, execute the steps defined above
# -----------------------------------------------------------------------------
main
