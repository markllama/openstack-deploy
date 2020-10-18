#!/bin/bash
#
# Prepare for and deploy an overcloud
#
SSL_CA_TEMPLATE=inject-trust-anchor-hiera.yaml

[ -f ~/ssl/${SSL_CA_TEMPLATE} ] &&  cp ~/ssl/${SSL_CA_TEMPLATE} ~/templates

# Generate RHEL subscription values
#
function write_rhel_credentials() {

    if [ ! -r ~/rhel_credentials.sh ] ; then
        echo FATAL: no rhel credentials file
        exit 2
    fi
    
    cat <<EOF >> ~/templates/rhel_registration.yaml
# Generated before the start of deployment from ~stack/rhel_credentials.sh
parameter_defaults:
  rhel_reg_user: \"${SM[USERNAME]}\"
  rhel_reg_password: \"${SM[PASSWORD]}\"
  rhel_reg_pool_id: \"${SM[POOLID]}\"
EOF
}

if [ ! -r templates/rhel_registration.yaml ] ; then
    write_rhel_credentials
fi

source ~/stackrc

openstack overcloud deploy --verbose \
          --stack lab \
          --templates \
          --environment-directory ~stack/templates
          
