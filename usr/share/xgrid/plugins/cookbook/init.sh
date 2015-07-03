#!/bin/bash

if [ ! -e /var/lib/xgrid/firstboot ]; then
  echo "Not first boot, exiting"
  exit 0
fi

if [ -e /mnt/context.sh ]; then
  . /mnt/context.sh
fi


if [ -e /var/lib/xgrid/ec2.properties ]; then
  . /var/lib/xgrid/ec2.properties
fi

gem install chef -v 11.16.4 --no-ri --no-rdoc

if [ -n "$CHEFSERVER" ]; then

  sed -i "s/@@chefserver = '.*'/@@chefserver = '"$CHEFSERVER"'/" /usr/share/xgrid/web/xgridconfig.rb

  # if custom key is submit
  if [ $CHEFVALIDATIONKEY != "default" ]; then

	  # chef custom key, erase default key
	  echo "-----BEGIN RSA PRIVATE KEY-----" > /usr/share/xgrid/web/chef_keys/chef-validator.pem
	  echo $CHEFVALIDATIONKEY | sed s/" "/"\n"/g >> /usr/share/xgrid/web/chef_keys/chef-validator.pem
	  echo "-----END RSA PRIVATE KEY-----" >> /usr/share/xgrid/web/chef_keys/chef-validator.pem
  fi

  # add module in xgrid.yaml
  sed -i "s/modules: Xgrid/modules: Xgrid,XgridCookbook/" /etc/xgrid/xgrid.yaml

  # edit the welcome apache page
  sed -i "s/<\/div><div class=\"footer\">/<h2>CHEF cookbooks installation<\/h2><p>You can install some CHEF <b>cookbooks<\/b> via <a href=\/xgrid>Xgrid<\/a> web application<\/p><\/div><div class=\"footer\">/" /var/www/index.html

fi
