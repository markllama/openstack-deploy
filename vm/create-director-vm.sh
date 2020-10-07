#!/bin/bash
#
: ${DATA_DIR=$(dirname $0)}
: ${SECRETS_JSON=~/secrets.json}

# start python web server
# make sure port 8000 is open
: ${RHEL_VERSION=7.8}
: ${KS_PORT=8080}
: ${VM_NAME=osp-13}

#sudo firewall-cmd --zone libvirt --add-port 8080/tcp

PYTHON_MAJOR=$(python --version | cut -d' ' -f2 | cut -d. -f1)

function start_httpd() {
    local data_dir=$1
    local cwd=$(pwd)
    
    cd $data_dir ;
    if [ ${PYTHON_MAJOR} -eq 2 ] ; then
        python -m SimpleHTTPServer ${KS_PORT} &
    else
        python -m http.server ${KS_PORT} &
    fi
    cd ${cwd}
}

function generate_kickstart_file() {
    local data_dir=$1
    local secrets_file=$2
    
    jinja2 ${data_dir}/vm-anaconda-ks.cfg.j2  ${secrets_file} \
           > ${data_dir}/vm-anaconda-ks.cfg
}

trap 'kill $(jobs -p)' EXIT INT HUP

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
     --extra-args "console=ttyS0 ip=192.168.1.81::192.168.1.1:255.255.255.0:director.lab.lamourine.org:eth0:none ks=http://192.168.1.100:${KS_PORT}/vm-anaconda-ks.cfg" \
     --os-type=linux \
     --os-variant=rhel${RHEL_VERSION} \
     --location=/home/libvirt/images/rhel-server-${RHEL_VERSION}-x86_64-dvd.iso \
     --network bridge:br-ext \
     --network bridge:br-ipmi \
     --network bridge:br-prov \
     --network bridge:br-data

rm ${DATA_DIR}/vm-anaconda-ks.cfg
