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


if [ "$SGE" = "master" ]; then
echo "Installing packages"
DEBIAN_FRONTEND='noninteractive' apt-get -y install gridengine-master gridengine-client
# Update config
sed  -i 's/none/'$DOMAIN'/' /etc/gridengine/bootstrap
su -s /bin/sh -c "/usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin" sgeadmin


fi
if [ "$SGE" = "node" ]; then

fi
