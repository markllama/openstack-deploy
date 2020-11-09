#!/bin/bash

declare -A MACS=(
    [ext]=74:46:a0:b4:eb:87
    [ilom]=00:e0:4c:87:00:58
    [prov]=00:e0:4c:67:92:37
    [data]=00:e0:4c:87:00:57
)

NICS=(eno1 eth1 eth3 ens1 ens2)


function get_nic_by_mac() {
    local mac=$1
    ip link | grep -B1 ${mac} | head -1 |cut -d' ' -f2 | tr -d :
}

function get_mac_by_nic() {
    local nic=$1
    ip link | grep -A1 ${nic} | tail -1 | awk '{print $2}'
}

# for each network, find the nic with the correct mac
for NET in "${!MACS[@]}" ; do
    NIC=$(get_nic_by_mac ${MACS[$NET]})
    echo net $NET is on device ${NIC}
done
    

