#!/bin/bash

SSL_CA_TEMPLATE=inject-trust-anchor-hiera.yaml

[ -f ~/ssl/${SSL_CA_TEMPLATE}] &&  cp ~/ssl/${SSL_CA_TEMPLATE} ~/templates

source ~/stackrc

openstack overcloud deploy --verbose \
          --stack lab \
          --templates \
          --environment-directory ~stack/templates
          
