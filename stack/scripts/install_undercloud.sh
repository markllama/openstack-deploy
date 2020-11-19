#!/bin/bash
#
# Install and configure the undercloud on a host
#
set -u # Exit for undefined variables

function is_redhat() {
    [ -r /etc/redhat-release ] && grep -q 'Red Hat' /etc/redhat-release
}


# Credentials shouldn't be saved in a file on github
# Source them locally to fill them in for the scripts
#
function load_rh_credentials() {
    : ${SM_FILE=~/rhel_credentials.sh}
    if [ ! -r ${SM_FILE} ] ; then
        echo "FATAL: Missing credentials file ${SM_FILE}"
        echo "Required to install container images"
        #    exit 2
     fi
    source ${SM_FILE}
}

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

    # Load RH credentials for access to the RH repos for vm and container images
    if is_redhat ; then
        load_rh_credentials

        import_rh_vm_images
        import_rh_container_images
    else
        import_centos_vm_images
        echo ADD CENTOS CODE
    fi

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

function import_rh_vm_images() {

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

function import_rh_container_images() {
    
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

function import_centos_vm_images() {
    : ${REPO_URL:="https://images.rdoproject.org/centos7/queens/rdo_trunk/current-tripleo-rdo/"}
    : ${IMAGE_DIR:=~/images}

    DOWNLOAD_FILES=(
        ironic-python-agent.tar
        overcloud-full.tar
        undercloud.qcow2
    )

    mkdir -p ${IMAGE_DIR}

    for FILE in ${DOWNLOAD_FILES[@]} ; do
        [ -f ${IMAGE_DIR}/${FILE} ] || curl -o ${IMAGE_DIR}/${FILE} ${REPO_URL}${FILE}
        [ -f ${IMAGE_DIR}/${FILE}.mp3 ] || curl -o ${IMAGE_DIR}/${FILE}.md5 ${REPO_URL}${FILE}.md5
    done

    for TAR in ${IMAGE_DIR}/*.tar ; do
        tar -C ${IMAGE_DIR} -xf ${TAR}
    done

    openstack overcloud image upload --image-path ${IMAGE_DIR}
}

function import_centos_container_images() {
    sudo yum install https://trunk.rdoproject.org/centos7/current/python2-tripleo-repos-0.0.1-0.20200409224957.8bac392.el7.noarch.rpm

    sudo -E tripleo-repos -b queens current
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
