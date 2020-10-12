#!/bin/bash

source ~/stackrc

openstack overcloud deploy --verbose \
          --stack lab \
          --templates \
          --environment-directory ~stack/templates
          
