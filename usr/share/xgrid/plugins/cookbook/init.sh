#!/bin/bash

if [ ! -e /var/lib/xgrid/firstboot ]; then
  echo "Not first boot, exiting"
  exit 0
fi

if [ ! -e /mnt/context.sh ]; then
  echo "No context file available, exiting"
  exit 1
fi

. /mnt/context.sh

if [ -e /var/lib/xgrid/ec2.properties ]; then
  . /var/lib/xgrid/ec2.properties
fi


if [ -n "$CHEFSERVER" ]; then

  gem install chef --no-ri --no-rdoc

  # chef section configuration
  sed -i "s/@@chefserver = '.*'/@@chefserver = '"$CHEFSERVER"'/" /usr/share/xgrid/web/xgridconfig.rb
  echo "-----BEGIN RSA PRIVATE KEY-----" > /usr/share/xgrid/web/chef_keys/chef-validator.pem
  echo $CHEFVALIDATIONKEY | sed s/" "/"\n"/g >> /usr/share/xgrid/web/chef_keys/chef-validator.pem
  echo "-----END RSA PRIVATE KEY-----" >> /usr/share/xgrid/web/chef_keys/chef-validator.pem

  # add module in xgrid.yaml
  sed -i "s/modules: Xgrid/modules: Xgrid,XgridCookbook/" /etc/xgrid/xgrid.yaml


fi
