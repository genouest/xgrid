#!/bin/bash

if [ -e /var/lib/gone/firstboot ]; then
  echo "Not first boot, exiting"
  exit 0
fi

if [ ! -e /mnt/context.sh ]; then
  echo "No context file available, exiting"
  exit 1
fi

. /mnt/context.sh

if [ -e  /var/lib/gone/ec2.properties ]; then
  . /var/lib/gone/ec2.properties
fi

TEMPLATES=/usr/share/xgrid/templates

if [ "$SGE" = "master" ]; then
  echo "Installing packages"
  DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-master gridengine-client
  # Update config
  sed  -i 's/none/'$DOMAIN'/' /etc/gridengine/bootstrap
  su -s /bin/sh -c "/usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin" sgeadmin

  # Define queue
  perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' $TEMPLATES/genocloud.queue.tpl > /tmp/genocloud.queue
  qconf -Aq /tmp/genocloud.queue
  # Add user
  export USER="vuser"
  perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' $TEMPLATES/genocloud.user.tpl > /tmp/genocloud.user
  qconf -Auser /tmp/genocloud.user
  # Set current as submit host
  qconf -as $HOSTNAME.$DOMAIN
  # Define allhosts group
  cp $TEMPLATES/genocloud.hostgroup.tpl /tmp/genocloud.hostgroup
  qconf -Ahgrp /tmp/genocloud.hostgroup

  DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-exec

  # Add exports
  echo "/var/spool/gridengine 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/var/lib/gridengine 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/usr/lib/gridengine 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  exportfs -ra

  # Web frontend
  gem install dm-core dm-sqlite-adapter dm-migrations amazon-ec2 rake
  sed -i "s/@@ip = ''/@@ip = '"$IP"'/" /usr/share/xgrid/web/xgridconfig.rb
  # @@baseurl = ''
  LASTIP=`echo $IP| cut -d"." -f4`
  sed -i "s/@@baseurl = ''/@@baseurl = 'http://genocloud.genouest.org/cloud/"$LASTIP"/xgrid'/" /usr/share/xgrid/web/xgridconfig.rb
fi
if [ "$SGE" = "node" ]; then
  mkdir -p /var/spool/gridengine
  mount -t nfs $SGEMASTER:/var/spool/gridengine /var/spool/gridengine
  mkdir -p /var/lib/gridengine
  mount -t nfs $SGEMASTER:/var/lib/gridengine /var/lib/gridengine
  mkdir -p /usr/lib/gridengine
  mount -t nfs $SGEMASTER:/usr/lib/gridengine /usr/lib/gridengine
  DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-exec  gridengine-client
  sed  -i 's/none/'$DOMAIN'/' /etc/gridengine/bootstrap
  ruby /usr/share/xgrid/sendstatus.rb -master $SGEMASTER -host $HOSTNAME -xid $XGRIDID
fi
