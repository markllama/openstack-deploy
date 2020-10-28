#!/bin/bash
#
set -u # exit with error for undefined variables
#
# Prepare for and deploy an overcloud
#
SSL_CA_TEMPLATE=inject-trust-anchor-hiera.yaml

#[ -f ~/ssl/${SSL_CA_TEMPLATE} ] &&  cp ~/ssl/${SSL_CA_TEMPLATE} ~/templates

# Generate RHEL subscription values
#
function write_rhel_credentials() {

    if [ ! -r ~/rhel_credentials.sh ] ; then
        echo FATAL: no rhel credentials file
        exit 2
    fi

    source ~/rhel_credentials.sh
    
    cat <<EOF >> ~/templates/rhel_registration.yaml
# Generated before the start of deployment from ~stack/rhel_credentials.sh
resource_registry:
  OS::TripleO::NodeExtraConfig: /home/stack/templates/rhel-registration/rhel-registration.yaml
parameter_defaults:
  rhel_reg_method: "portal"
  rhel_reg_user: "${SM[USERNAME]}"
  rhel_reg_password: "${SM[PASSWORD]}"
  rhel_reg_pool_id: "${SM[POOLID]}"

  rhel_reg_activation_key: ""
  rhel_reg_auto_attach: ""
  rhel_reg_base_url: ""
  rhel_reg_environment: ""
  rhel_reg_force: ""
  rhel_reg_machine_name: ""
  rhel_reg_org: ""
  rhel_reg_password: ""
  rhel_reg_pool_id: ""
  rhel_reg_release: ""
  rhel_reg_repos: ""
  rhel_reg_sat_url: ""
  rhel_reg_server_url: ""
  rhel_reg_service_level: ""
  rhel_reg_user: ""
  rhel_reg_type: ""
  rhel_reg_sat_repo: ""
  rhel_reg_http_proxy_host: ""
  rhel_reg_http_proxy_port: ""
  rhel_reg_http_proxy_username: ""
  rhel_reg_http_proxy_password: ""

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
          
