#!/bin/bash
#
: ${DATA_DIR=$(dirname $0)}
: ${SECRETS_JSON=~/secrets.json}

# start python web server
# make sure port 8000 is open
: ${CENTOS_VERSION=7}
: ${KS_PORT=8080}
: ${VM_NAME=rdo-queens}
: ${PYTHON=python3}

#sudo firewall-cmd --zone libvirt --add-port 8080/tcp

PYTHON_MAJOR=$(${PYTHON} --version | cut -d' ' -f2 | cut -d. -f1)

function start_httpd() {
    local data_dir=$1
    local cwd=$(pwd)
    
    cd $data_dir ;
    if [ ${PYTHON_MAJOR} -eq 2 ] ; then
        ${PYTHON} -m SimpleHTTPServer ${KS_PORT} &
    else
        ${PYTHON} -m http.server ${KS_PORT} &
    fi
    cd ${cwd}
}

function generate_kickstart_file() {
    local data_dir=$1
    local secrets_file=$2
    
    jinja2 ${data_dir}/vm-centos7-ks.cfg.j2  ${secrets_file} \
           > ${data_dir}/vm-centos7-ks.cfg
}

trap 'jobs -p | xargs kill' EXIT INT HUP

generate_kickstart_file ${DATA_DIR} ${SECRETS_JSON}

start_httpd ${DATA_DIR}

sudo virt-install \
     --name=${VM_NAME} \
     --nographics \
     --sound=none \
     --console pty,target_type=serial  \
     --vcpus=2 \
     --ram=10240 \
     --disk size=100,sparse=no \
     --extra-args "console=ttyS0 ip=192.168.1.81::192.168.1.1:255.255.255.0:director.lab.lamourine.org:eth0:none ks=http://192.168.1.100:${KS_PORT}/vm-centos7-ks.cfg" \
     --os-type=linux \
     --os-variant=centos7.0 \
     --location=/home/libvirt/images/CentOS-7-x86_64-DVD-2009.iso \
     --network bridge:br-ext \
     --network bridge:br-ipmi \
     --network bridge:br-prov \
     --network bridge:br-data

rm ${DATA_DIR}/vm-centos7-ks.cfg
