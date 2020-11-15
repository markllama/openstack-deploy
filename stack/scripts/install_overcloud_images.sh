#!/bin/bash

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

openstack overcloud image upload

#declare -A IMAGE_FILES=(
#    ['overcloud-full-vmlinuz']=overcloud-full.vmlinuz
#    ['overcloud-full-initrd']=overcloud-full.initrd
#    ['overcloud-full']=overcloud-full.qcow2
#    ['bm-deploy-kernel']=ironic-python-agent.kernel
#    ['bm-deploy-ramdisk']=ironic-python-agent.initramfs
#)

