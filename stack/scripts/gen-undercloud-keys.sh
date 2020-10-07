#!/bin/bash 
#
#
#
DIRECTOR_HOSTNAME=director.lab.lamourine.org
UNDERCLOUD_PUBLIC_IP=172.16.3.4
UNDERCLOUD_ADMIN_IP=172.16.3.5

SSLDIR=~stack/sslfiles
mkdir -p ${SSLDIR}

main() {
    write_undercloud_conf
    create_ca_private_key
    self_sign_ca_certificate
    create_undercloud_sign_request
    sign_undercloud_certificate
    install_ca_cert
    create_trust_file
}


function write_undercloud_conf() {
    cat > ${SSLDIR}/openssl-undercloud.conf <<EOF
# If CN is an IP, include that IP as a SAN
# RFC 2818
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req

[req_distinguished_name]
commonName_max = 64

[ v3_req ]
basicConstraints = CA:FALSE
subjectAltName = @alt_names

[ alt_names ]
IP.1 = ${UNDERCLOUD_PUBLIC_IP}
IP.2 = ${UNDERCLOUD_ADMIN_IP}
DNS.1 = ${UNDERCLOUD_PUBLIC_IP}
DNS.2 = ${UNDERCLOUD_ADMIN_IP}
EOF
}


function create_ca_private_key() {
    openssl genrsa -out ${SSLDIR}/director-ca-privkey.pem 2048
}

function self_sign_ca_certificate() {
    openssl req \
            -subj "/C=US/ST=Texas/L=San Antonio/O=RPC-R/CN=${DIRECTOR_HOSTNAME}" \
            -new -x509 \
            -key ${SSLDIR}/director-ca-privkey.pem \
            -out ${SSLDIR}/director-cacert.pem \
            -days 3650
}

function create_undercloud_sign_request() {
    openssl req \
            -subj "/C=US/ST=Texas/L=San Antonio/O=RPC-R/CN=${UNDERCLOUD_PUBLIC_IP}" \
            -newkey rsa:2048 \
            -days 3650 \
            -config ${SSLDIR}/openssl-undercloud.conf \
            -extensions v3_req \
            -nodes \
            -keyout ${SSLDIR}/undercloud.key \
            -out ${SSLDIR}/undercloud-req.pem
}

function sign_undercloud_certificate() {
    openssl rsa -in ${SSLDIR}/undercloud.key -out ${SSLDIR}/undercloud.key
    openssl x509 \
            -req \
            -extfile ${SSLDIR}/openssl-undercloud.conf \
            -extensions v3_req \
            -in ${SSLDIR}/undercloud-req.pem \
            -days 3650 \
            -CA ${SSLDIR}/director-cacert.pem \
            -CAkey ${SSLDIR}/director-ca-privkey.pem \
            -set_serial 1000 \
            -out ${SSLDIR}/undercloud.crt
}

function install_ca_cert() {
    sudo mkdir -p /etc/pki/instack-certs
    cat ${SSLDIR}/undercloud.crt ${SSLDIR}/undercloud.key |
        sudo tee /etc/pki/instack-certs/undercloud.pem

    sudo semanage fcontext -a -t etc_t "/etc/pki/instack-certs(/.*)?"
    sudo restorecon -vvRF /etc/pki/instack-certs

    sudo cp ${SSLDIR}/director-cacert.pem /etc/pki/ca-trust/source/anchors/
    sudo update-ca-trust extract
    openssl verify -CAfile /etc/ssl/certs/ca-bundle.trust.crt ${SSLDIR}/undercloud.crt
}

# create inject-trust-anchor-hiera.yaml from new cert

function create_trust_file() {
    cat <<EOF > ${SSLDIR}/inject-trust-anchor-hiera.yaml
# *******************************************************************
# title: Inject SSL Trust Anchor on Overcloud Nodes
# description: |
#   When using an SSL certificate signed by a CA that is not in the default
#   list of CAs, this environment allows adding a custom CA certificate to
#   the overcloud nodes.
parameter_defaults:
  # Map containing the CA certs and information needed for deploying them.
  # Type: json
  CAMap:
    overcloud-ca:
      content: |
$(cat ${SSLDIR}/director-cacert.pem | sed 's/^/        /')

    undercloud-ca:
      content: |
$(cat ${SSLDIR}/director-cacert.pem | sed 's/^/        /')
EOF
}

##############################################################################
main
