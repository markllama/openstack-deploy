#!/bin/bash

: ${REPO_URL:="https://images.rdoproject.org/centos7/queens/rdo_trunk/current-tripleo-rdo/"}
: ${IMAGE_DIR:=~/images}

DOWNLOAD_FILES=(
    ironic-python-agent.tar
    overcloud-full.tar
    undercloud.qcow2
)

for FILE in ${DOWNLOAD_FILES[@]} ; do
    [ -f ${REPO_URL}${FILE} ] || wget -O ${IMAGE_DIR}/${FILE} ${REPO_URL}${FILE}
    [ -f ${REPO_URL}${FILE}.mp3 || wget -O ${IMAGE_DIR}/${FILE}.md5 ${REPO_URL}${FILE}.md5
done

for TAR in ${IMAGE_DIR}/*.tar ; do
    tar -xf ${TAR}
done
