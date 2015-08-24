#!/bin/bash

echo "SGE plugin"

if [ ! -e /var/lib/xgrid/firstboot ]; then
  echo "Not first boot, exiting"
  exit 0
fi

if [ -e /mnt/context.sh ]; then
  . /mnt/context.sh
else
  . /var/lib/xgrid/ec2.properties
  if [ "$SGE" = "master" ]; then
      MASTERHOSTNAME=`wget -qO- http://instance-data/latest/meta-data/hostname`
      IFS='.' read -a myarray <<< "$MASTERHOSTNAME"
      MASTERIP=`wget -qO- http://instance-data/latest/meta-data/local-ipv4`
      echo "$MASTERIP   ${myarray[0]}.localhost" > /opt/sgemaster
  else
      SLAVEHOSTNAME=`wget -qO- http://instance-data/latest/meta-data/hostname`
      hostname $SLAVEHOSTNAME
  fi
fi


if [ -e  /var/lib/xgrid/ec2.properties ]; then
  . /var/lib/xgrid/ec2.properties
fi

TEMPLATES=/usr/share/xgrid/plugins/sge/templates

if [ "$SGE" = "master" ]; then
  echo "Installing packages"
  #DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-master gridengine-client gridengine-drmaa1.0
  DEBIAN_FRONTEND='noninteractive' dpkg -i /usr/share/xgrid/3rdparty/gridengine-client_6.2u5-7.3_amd64.deb /usr/share/xgrid/3rdparty/gridengine-common_6.2u5-7.3_all.deb /usr/share/xgrid/3rdparty/gridengine-drmaa1.0_6.2u5-7.3_amd64.deb /usr/share/xgrid/3rdparty/gridengine-master_6.2u5-7.3_amd64.deb
  DEBIAN_FRONTEND='noninteractive' apt-get -y -f install
  # Update config
  if [ -n "$DOMAIN" ]; then
    sed  -i 's/none/'$DOMAIN'/' /etc/gridengine/bootstrap
  fi
  echo "Ignore fqdn"
  su -s /bin/sh -c "/usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin" sgeadmin
  sed -i "s/ignore_fqdn.*false/ignore_fqdn    true/" /var/lib/gridengine/default/common/bootstrap

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

  service gridengine-master restart

  #DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-exec
  DEBIAN_FRONTEND='noninteractive' dpkg -i /usr/share/xgrid/3rdparty/gridengine-common_6.2u5-7.3_all.deb /usr/share/xgrid/3rdparty/gridengine-exec_6.2u5-7.3_amd64.deb
  DEBIAN_FRONTEND='noninteractive' apt-get -y -f install
  sed -i "s/ignore_fqdn.*false/ignore_fqdn    true/" /var/lib/gridengine/default/common/bootstrap

  # Add exports
  echo "/var/spool/gridengine *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/var/lib/gridengine *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  echo "/usr/lib/gridengine *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports


  sed -i "s/modules: Xgrid/modules: Xgrid,XgridSge/" /etc/xgrid/xgrid.yaml

# edit the welcome apache page
sed -i "s/<\/div><div class=\"footer\">/<h2>SGE management<\/h2><p>You can access to <b>Xgrid<\/b> manager to deploy your SGE cluster <a href=\"\/xgrid\">here<\/a><\/p><\/div><div class=\"footer\">/" /var/www/html/index.html


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
  if [ -e /mnt/context.sh ]; then
      # wait for local update
      sleep 300
  else
      # Go for amazon
      sleep 20
  fi
  echo "Update node status"
  if [ -n "$DOMAIN" ]; then
      ruby /usr/share/xgrid/plugins/sge/sendstatus.rb --master $XGRIDMASTER --name $HOSTNAME.$DOMAIN --id $XGRIDID --key $KEY
  else
      ruby /usr/share/xgrid/plugins/sge/sendstatus.rb --master $XGRIDMASTER --name $HOSTNAME --id $XGRIDID --key $KEY
  fi
  sleep 60
  echo "Install grid node"
  if [ -e /opt/sgemaster ]; then
      cat /opt/sgemaster >> /etc/hosts
  fi

  #DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-exec
  DEBIAN_FRONTEND='noninteractive' dpkg -i /usr/share/xgrid/3rdparty/gridengine-common_6.2u5-7.3_all.deb /usr/share/xgrid/3rdparty/gridengine-exec_6.2u5-7.3_amd64.deb
  DEBIAN_FRONTEND='noninteractive' apt-get -y -f install

  if [ -n "$DOMAIN" ]; then
    sed  -i 's/none/'$DOMAIN'/' /etc/gridengine/bootstrap
  fi
  sed -i "s/ignore_fqdn.*false/ignore_fqdn    true/" /var/lib/gridengine/default/common/bootstrap
  service gridengine-exec restart
fi


touch /var/lib/xgrid/sge.done
