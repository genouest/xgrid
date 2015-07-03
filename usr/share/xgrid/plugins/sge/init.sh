#!/bin/bash

echo "SGE plugin"

if [ ! -e /var/lib/xgrid/firstboot ]; then
  echo "Not first boot, exiting"
  exit 0
fi

if [ -e /mnt/context.sh ]; then
  . /mnt/context.sh
fi


if [ -e  /var/lib/xgrid/ec2.properties ]; then
  . /var/lib/xgrid/ec2.properties
fi

TEMPLATES=/usr/share/xgrid/plugins/sge/templates

if [ "$SGE" = "master" ]; then
  echo "Installing packages"
  DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-master gridengine-client gridengine-drmaa1.0
  # Update config
  if [ -n "$DOMAIN" ]; then
    sed  -i 's/none/'$DOMAIN'/' /etc/gridengine/bootstrap
  fi
  su -s /bin/sh -c "/usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin" sgeadmin

  # Define queue
  perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' $TEMPLATES/genocloud.queue.tpl > /tmp/genocloud.queue
  qconf -Aq /tmp/genocloud.queue
  # Add user
  export USER="vuser"
  perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' $TEMPLATES/genocloud.user.tpl > /tmp/genocloud.user
  qconf -Auser /tmp/genocloud.user
  # Set current as submit host
  if [ -n "$DOMAIN" ]; then
    qconf -as $HOSTNAME.$DOMAIN
  else
    qconf -as $HOSTNAME
  fi
  # Define allhosts group
  cp $TEMPLATES/genocloud.hostgroup.tpl /tmp/genocloud.hostgroup
  qconf -Ahgrp /tmp/genocloud.hostgroup

  DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-exec

  # Add exports
  echo "/var/spool/gridengine 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/var/lib/gridengine 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/usr/lib/gridengine 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports

  sed -i "s/modules: Xgrid/modules: Xgrid,XgridSge/" /etc/xgrid/xgrid.yaml

# edit the welcome apache page
sed -i "s/<\/div><div class=\"footer\">/<h2>SGE management<\/h2><p>You can access to <b>Xgrid<\/b> manager to deploy your SGE cluster <a href=\"\/xgrid\">here<\/a><\/p><\/div><div class=\"footer\">/" /var/www/index.html


fi
if [ "$SGE" = "node" ]; then
  mkdir -p /var/spool/gridengine
  mount -t nfs -o vers=3 $SGEMASTER:/var/spool/gridengine /var/spool/gridengine
  mkdir -p /var/lib/gridengine
  mount -t nfs -o vers=3 $SGEMASTER:/var/lib/gridengine /var/lib/gridengine
  mkdir -p /usr/lib/gridengine
  mount -t nfs -o vers=3 $SGEMASTER:/usr/lib/gridengine /usr/lib/gridengine
  # Wait for DNS to be ready (5 minutes refresh)
  echo "Waiting for DNS refresh"
  sleep 300
  echo "Update node status"
  ruby /usr/share/xgrid/plugins/sge/sendstatus.rb --master $XGRIDMASTER --name $HOSTNAME.$DOMAIN --id $XGRIDID --key $KEY
  sleep 60
  echo "Install grid node"
  DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-exec
  if [ -n "$DOMAIN" ]; then
    sed  -i 's/none/'$DOMAIN'/' /etc/gridengine/bootstrap
  fi
fi


touch /var/lib/xgrid/sge.done
