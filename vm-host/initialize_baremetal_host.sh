#!/bin/bash
#
# Initialize the baremetal host:
#
# * Register the host with subscription-manager
# 
# * Install libvirt packages
# * enable IP forwarding
#
# * create network bridges
# ** br-ipmi
# ** br-ctlplane
#
# * libvirt config
# ** create default network
# ** create default pool
# ** install boot DVD ISO
#

: ${SECRETS_FILE=openstack-secrets.json}

function main() {

    [ -r ${SECRETS_FILE} ] && resolve_variables ${SECRETS_FILE}

    enable_serial_login 1
    enable_serial_console 1
    subscribe_system
    remove_network_manager
    install_tools
    install_libvirt
    initialize_libvirt_default_pool
    initialize_libvirt_default_net
    enable_ip_forwarding
    create_bridge ext eno1
    create_bridge ipmi rt2p2
    create_bridge prov rt1p2
    create_bridge data rt2p1
}


function resolve_variables() {
    local secrets_file=$1

    declare -A SM

    SM[USERNAME]=$(jq --raw-output .sm.username)
    SM[PASSWORD]=$(jq --raw-output .sm.password)
    SM[POOLID]=$(jq --raw-output .sm.pool_id)
}

function remove_network_manager() {
    systemctl disable --now NetworkManager
    yum remove -y NetworkManager NetworkManager-libnm NetworkManager-config-server
}

# Subscribe Host to Red Hat Portal
function subscribe_system() {
    if subscription-manager status 2>&1 >/dev/null ; then
        echo "INFO: subscribed"
        return 0
    fi

    subscription-manager register \
        --username "${SM[USERNAME]}" \
        --password "${SM[PASSWORD]}"
    subscription-manager attach \
        --pool "${SM[POOLID]}"
}


# Install packages
function install_tools() {
    yum -y install \
        tmux nmap traceroute bind-utils openldap-clients tcpdump strace
}

function install_libvirt() {
    yum -y install \
        libvirt-client libvirt-daemon \
        qemu-kvm libvirt-daemon-driver-qemu \
        libvirt-daemon-kvm virt-install \
        bridge-utils rsync virt-viewer
    yum -y update

    systemctl enable libvirtd
    systemctl start libvirtd

}

# Create default volume pool and network for libvirt
function initialize_libvirt_default_pool() {

    if virsh pool-info default 2>&1 >/dev/null ; then
        echo INFO: default pool exists
        return 0
    fi

    mkdir -p /home/libvirt/images
    
    local pool_xml=$(mktemp).xml

    cat <<EOF > ${pool_xml}
<pool type='dir'>
  <name>default</name>
  <target>
    <path>/home/libvirt/images</path>
    <permissions>
      <mode>0755</mode>
      <owner>0</owner>
      <group>0</group>
      <label>system_u:object_r:unlabeled_t:s0</label>
    </permissions>
  </target>
</pool>
EOF

    # initialize the default volume pool
    virsh pool-define ${pool_xml}
    rm -f ${pool_xml}
    virsh pool-start default
    virsh pool-autostart default
}

function initialize_libvirt_default_net() {

    if virsh net-info default 2>&1 >/dev/null ; then
        echo INFO: default net exists
        return 0
    fi
        
    # Initialize the default network
    TMPFILE_XML=$(mktemp).xml
    cat <<EOF > ${TMPFILE_XML}
<network connections='1'>
  <name>default</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
    
    virsh net-define ${TMPFILE_XML}
    rm -f ${TMPFILE_XML}
    virsh net-start default
    virsh net-autostart default
}

# Enable IP forwarding in the kernel
function enable_ip_forwarding() {
    if [ ! -f /etc/sysctl.d/ip_forward.conf ] ; then
        echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/ip_forward.conf
    fi
    sysctl -p /etc/sysctl.d/ip_forward.conf
}


function create_bridge() {
    local bridge_name=$1
    local iface_name=$2

    cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-br-${bridge_name}
DEVICE=br-${bridge_name}
NAME=br-${bridge_name}
ONBOOT=yes
HOTPLUG=no
NM_CONTROLLED=no
PEERDNS=no
TYPE=Bridge
MTU=1500
BOOTPROTO=static
EOF

    cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-${iface_name}
DEVICE=${iface_name}
NAME=${iface_name}
TYPE=Ethernet
BRIDGE=br-${bridge_name}
ONBOOT=yes
BOOTPROTO=none
HOTPLUG=no
NM_CONTROLLED=no
MTU=1500
EOF

}

function enable_serial_login() {
    local serial_port_number=$1

    if systemctl --quiet is-active serial-getty@ttyS${serial_port_number}.service ; then
	echo "INFO: serial port tty${serial_port_number} is active"
	return 0
    fi
    
    cp /usr/lib/systemd/system/serial-getty@.service \
       /etc/systemd/system/serial-getty@ttyS${serial_port_number}.service
    sed -i -e "/ExecStart/s/\$TERM/tty${serial_port_number}/"
    ln -s /etc/systemd/system/serial-getty@ttyS${serial_port_number}.service \
       /etc/systemd/system/getty.target.wants/
    systemctl enable serial-getty@ttyS${serial_port_number}.service --now
}

function enable_serial_console() {

    local serial_port_number=$1
    local grub_file=/etc/default/grub

    if grep --quiet GRUB_SERIAL_COMMAND ${grub_file} ; then
	echo INFO: serial console already enabled in grub2
        return 0
    fi
    
    sed -i -e '/DISABLE_SUBMENU/s/=.*/=false/' ${grub_file}
    sed -i -e '/DISABLE_RECOVERY/s/=.*/=false/' ${grub_file}
    # GRUB_TERMINAL_OUTPUT-*append "serial"
    sed -i -e '/TERMINAL_OUTPUT/s/"console"/"console serial"/' ${grub_file}
    # GRUB_CMDLINE_LINUX- (s/\s+rhgb//;s/\s+quiet//;s/$/ console=tty0 console=ttyS{serial_port_number}/"
    sed -i -e "/CMDLINE_LINUX/{s/ rhgb//;s/ quiet//;s/\"$/ console=tty0 console=ttyS${serial_port_number},115200\"/}" ${grub_file}
    # 
    cat <<EOF >> ${grub_file}
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=${serial_port_number} --word=8 --parity=no --stop=1"
EOF

    grub2-mkconfig -o /boot/grub2/grub.cfg
}

# =============================================================================
# MAIN
# =============================================================================
# See the main function at the top
main
