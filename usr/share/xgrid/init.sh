#!/bin/bash

if [ ! -e /mnt/context.sh ]; then
  echo "No context file available, exiting"
  exit 1
fi

. /mnt/context.sh

if [ -e  /var/lib/gone/ec2.properties ]; then
  . /var/lib/gone/ec2.properties
fi

if [ -e /var/lib/gone/firstboot ]; then
  if [ -z $XGRIDMASTER ]; then
    # This is the xgridmaster
    echo "/var/lib/xgrid 192.168.2.0/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    # Web frontend
    gem install dm-core dm-sqlite-adapter dm-migrations amazon-ec2 rack
    sed -i "s/@@ip = ''/@@ip = '"$IP"'/" /usr/share/xgrid/web/xgridconfig.rb
    # @@baseurl = ''
    LASTIP=`echo $IP| cut -d"." -f4`
    sed -i "s/@@baseurl = ''/@@baseurl = 'http:\/\/genocloud.genouest.org\/cloud\/"$LASTIP"\/xgrid'/" /usr/share/xgrid/web/xgridconfig.rb
    RPASS=$(makepasswd --char=10)
    sed -i "s/@@adminpwd = 'admin'/@@adminpwd = '"$RPASS"'/" /usr/share/xgrid/web/xgridconfig.rb
    echo "Starting xgrid web server"
    service xgrid restart
  else
    # This is a xgrid node
    mount -t nfs $XGRIDMASTER:/var/lib/xgrid /var/lib/xgrid
    # RRD collect
    xgrid-rrdcreate $HOSTNAME.$DOMAIN
    echo "step = 60" > /etc/rrdcollect.conf
    echo "directory = /var/lib/xgrid/rrdcollect/"$HOSTNAME.$DOMAIN >> /etc/rrdcollect.conf
    echo "file:///proc/meminfo" >> /etc/rrdcollect.conf
    echo "/^MemTotal:\s*(\d+) kB/         mem.rrd:mem_total" >> /etc/rrdcollect.conf
    echo "/^MemFree:\s*(\d+) kB/          mem.rrd:mem_free" >> /etc/rrdcollect.conf
    echo "file:///proc/stat" >> /etc/rrdcollect.conf
    echo "/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/  cpu.rrd:cpu_user,cpu_nice,cpu_system,cpu_idle,cpu_iowait,cpu_irq,cpu_softirq" >> /etc/rrdcollect.conf
    echo "" > /etc/default/rrdcollect
    service rrdcollect restart
  fi
fi

for f in /usr/share/xgrid/plugins/*/init.sh
do
  echo "Execute plugin init: "$f
  bash $f
done

if [ -z $XGRIDMASTER ]; then
  exportfs -ra
fi

