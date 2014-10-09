#!/bin/bash

# If OpenNebula, get EC2_USER_DATA from context file
if [ -e /mnt/context.sh ]; then
  . /mnt/context.sh
  cp /mnt/context.sh /var/lib/xgrid/context.sh

  if [ -n "$EC2_USER_DATA" ]; then
    /usr/share/xgrid/one-ec2.rb $EC2_USER_DATA
  fi
fi

# cloud-init user data file
if [ -e /var/lib/cloud/instance/user-data.txt ]; then
    rm -f /var/lib/xgrid/ec2.properties
    ln -s /var/lib/cloud/instance/user-data.txt /var/lib/xgrid/ec2.properties
fi

if [ -e  /var/lib/xgrid/ec2.properties ]; then
  . /var/lib/xgrid/ec2.properties
fi

if [ -n "$ETH0_MASK" ]; then
  export MASK=$ETH0_MASK
else
  export MASK="192.168.2.0"
fi

if [ -n "$ETH0_IP" ]; then
  export IP=$ETH0_IP
else
  export IP=`hostname  -I | cut -f1 -d' '`
fi


if [ -z $XGRID_EC2_PORT ]; then
  export XGRID_EC2_PORT=4567
fi

if [ -e /var/lib/xgrid/firstboot ]; then

  apt-get update

  # Mount omaha-beach
  echo "Mount user esb"
  mkdir -p /omaha-beach

  if [ -n "$SHAREDFS" ]; then
    echo $SHAREDFS" /omaha-beach   nfs _netdev,defaults  0  0" >> /etc/fstab
    mount -a
  fi


  if [ -n "$DOMAIN" ]; then
    domainname $DOMAIN
    DOMAIN=$DOMAIN
  else
    DOMAIN=localhost
  fi


  if [ -n "$HOSTNAME" ]; then
    echo $HOSTNAME > /etc/hostname
    echo $IP" "$HOSTNAME.$DOMAIN" "$HOSTNAME >> /etc/hosts
    hostname $HOSTNAME
  fi


  if [ -z $XGRIDMASTER ]; then
    # This is the xgridmaster
    sed -i '/xgrid/d' /etc/exports
    echo "/var/lib/xgrid "$MASK"/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    echo "/opt "$MASK"/255.255.255.0(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    # Web frontend
    gem install dm-core dm-sqlite-adapter dm-migrations amazon-ec2 rack rack-protection --no-ri --no-rdoc
    if [ -n $XGRID_AMI ]; then
    sed -i "s/@@ami = '.*'/@@ami = '"$XGRID_AMI"'/" /usr/share/xgrid/web/xgridconfig.rb
    fi
    sed -i "s/@@url = '.*'/@@url = '"$XGRID_EC2"'/" /usr/share/xgrid/web/xgridconfig.rb
    sed -i "s/@@port = '.*'/@@port = '"$XGRID_EC2_PORT"'/" /usr/share/xgrid/web/xgridconfig.rb
    sed -i "s/@@ip = '.*'/@@ip = '"$IP"'/" /usr/share/xgrid/web/xgridconfig.rb
    sed -i "s/@@hostname = '.*'/@@hostname = '"$HOSTNAME"'/" /usr/share/xgrid/web/xgridconfig.rb

    # @@baseurl = ''
    LASTIP=`echo $IP| cut -d"." -f4`
    sed -i "s/@@baseurl = '.*'/@@baseurl = 'http:\/\/cloud-"$LASTIP".genouest.org\/xgrid'/" /usr/share/xgrid/web/xgridconfig.rb
    if [ -z $XGRID_PWD ]; then
    	XGRID_PWD=$(makepasswd --char=10)
    fi
    sed -i "s/@@adminpwd = '.*'/@@adminpwd = '"$XGRID_PWD"'/" /usr/share/xgrid/web/xgridconfig.rb
    echo $XGRID_PWD > /root/admin_pwd
    export APIKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    sed -i "s/@@apikey = '.*'/@@apikey = '"$APIKEY"'/" /usr/share/xgrid/web/xgridconfig.rb
    # Mysql, listen on all interfaces
    sed -i "s/127.0.0.1/0.0.0.0/" /etc/mysql/my.cnf
    service mysql restart
    echo "Starting xgrid web server" >> /var/log/xgrid.log

    # edit the welcome apache page
    echo '<html><body><h1>It works!</h1><p>Welcome to your virtual machine</p></body></html>' > /var/www/index.html

  else
    # This is a xgrid node
    mount -t nfs -o vers=3 $XGRIDMASTER:/var/lib/xgrid/rrdcollect /var/lib/xgrid/rrdcollect
    mount -t nfs -o vers=3 $XGRIDMASTER:/opt /opt

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

if [ ! -e /var/lib/xgrid/firstboot ]; then
  if [ -z $XGRIDMASTER ]; then
    echo "Not first boot, nothing to do on master"
  else
    # This is a xgrid node
    mount -t nfs -o vers=3 $XGRIDMASTER:/var/lib/xgrid/rrdcollect /var/lib/xgrid/rrdcollect
    mount -t nfs -o vers=3 $XGRIDMASTER:/opt /opt
  fi
fi


for f in /usr/share/xgrid/plugins/*/init.sh
do
  echo "Execute plugin init: "$f >> /var/log/xgrid.log
  bash $f  >> /var/log/xgrid.log
done

if [ -e /var/lib/xgrid/firstboot ]; then
  echo "Deleting firstboot" >> /var/log/xgrid.log
  rm /var/lib/xgrid/firstboot
fi

if [ -z $XGRIDMASTER ]; then
  exportfs -ra
  service nfs-kernel-server restart

  service xgrid stop >> /var/log/xgrid.log
  service xgrid start >> /var/log/xgrid.log


  # Should we start nodes ?
  if [ -z $XGRID_AMI ]; then
      echo "No node execution requested" >>  /var/log/xgrid.log
  else
      echo "Start nodes" >> /var/log/xgrid.log
      sleep 15
      ruby /usr/share/xgrid/web/xgrid-addnode.rb -i $XGRID_AMI -s $XGRID_AMITYPE -t $XGRID_NODETYPE -k $APIKEY -a $XGRID_EC2ACCESS -p $XGRID_EC2PASSWORD -q $XGRID_QUANTITY >> /var/log/xgrid.log
  fi
fi

  # edit the welcome apache page
  sed -i "s/<\/body>/<p>You can install some CHEF cookbooks via <a href=\/xgrid>Xgrid<\/a> web application<\/p><\/body>/" /var/www/index.html
fi

############################
#  Specific Xgrid version  #
############################

# for NGS image
#if [ -e /opt/install_NGS_tools.sh ]; then
#sh /opt/install_NGS_tools.sh
#mv /opt/install_NGS_tools.sh /tmp/
#fi

# for Galaxy image
# echo '<html><body><h1>It works!</h1><p>Welcome to your virtual machine</p><p>You can access to your Galaxy server <a href=/galaxy>here</a></p></body></html>' > /var/www/index.html
# sh /opt/galaxy-dist/run.sh --daemon

# for Galaxy proteomics image
# sed -i "s/<\/body>/<p>Trans Proteomic Pipeline GUI access <a href=\/tpp\/cgi-bin\/tpp_gui.pl> here<\/a><\/p><\/body>/" /var/www/index.html

