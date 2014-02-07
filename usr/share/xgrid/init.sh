#!/bin/bash

if [ ! -e /mnt/context.sh ]; then
  echo "No context file available, exiting"
  exit 1
fi

. /mnt/context.sh

if [ -e  /var/lib/gone/ec2.properties ]; then
  . /var/lib/gone/ec2.properties
fi

if [ -n "$ETH0_MASK" ]; then
  export MASK=$ETH0_MASK
else
  export MASK="192.168.2.0"
fi

if [ -z $XGRID_EC2_PORT ]; then
  export XGRID_EC2_PORT=4567
fi

if [ -e /var/lib/gone/firstboot ]; then
  if [ -z $XGRIDMASTER ]; then
    # This is the xgridmaster
    sed -i '/xgrid/d' /etc/exports
    echo "/var/lib/xgrid "$MASK"/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    # Web frontend
    gem install dm-core dm-sqlite-adapter dm-migrations amazon-ec2 rack rack-protection
    sed -i "s/@@url = '.*'/@@url = '"$XGRID_EC2"'/" /usr/share/xgrid/web/xgridconfig.rb
    sed -i "s/@@port = '.*'/@@port = '"$XGRID_EC2_PORT"'/" /usr/share/xgrid/web/xgridconfig.rb
    sed -i "s/@@ip = '.*'/@@ip = '"$IP"'/" /usr/share/xgrid/web/xgridconfig.rb
    # @@baseurl = ''
    LASTIP=`echo $IP| cut -d"." -f4`
    sed -i "s/@@baseurl = '.*'/@@baseurl = 'http:\/\/cloud-"$LASTIP".genouest.org\/xgrid'/" /usr/share/xgrid/web/xgridconfig.rb
    if [ -z $XGRID_PWD ]; then
    	XGRID_PWD=$(makepasswd --char=10)
    fi
    sed -i "s/@@adminpwd = '.*'/@@adminpwd = '"$XGRID_PWD"'/" /usr/share/xgrid/web/xgridconfig.rb
    export APIKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    sed -i "s/@@apikey = '.*'/@@apikey = '"$APIKEY"'/" /usr/share/xgrid/web/xgridconfig.rb
    # Mysql, listen on all interfaces
    sed -i "s/127.0.0.1/0.0.0.0/" /etc/mysql/my.cnf
    service mysql restart
    echo "Starting xgrid web server" >> /var/log/xgrid.log
    service xgrid restart >> /var/log/xgrid.log

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
    # mysql, required if client is needed
    mkdir -p /etc/mysql/conf.d
  fi
fi

for f in /usr/share/xgrid/plugins/*/init.sh
do
  echo "Execute plugin init: "$f
  bash $f  >> /var/log/xgrid.log
done

if [ -z $XGRIDMASTER ]; then
  exportfs -ra
  service nfs-kernel-server restart

  # Should we start nodes ?
  if [ -z $XGRID_AMI ]; then
      echo "No node execution requested" >>  /var/log/xgrid.log
  else
      echo "Start nodes" >> /var/log/xgrid.log
      sleep 15
      ruby /usr/share/xgrid/web/xgrid-addnode.rb -i $XGRID_AMI -s $XGRID_AMITYPE -t $XGRID_NODETYPE -k $APIKEY -a $XGRID_EC2ACCESS -p $XGRID_EC2PASSWORD -q $XGRID_QUANTITY >> /var/log/xgrid.log
  fi
fi

