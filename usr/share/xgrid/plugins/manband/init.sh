#!/bin/bash

if [ ! -e /var/lib/gone/firstboot ]; then
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


if [ "$WORKFLOW" = "master" ]; then
  echo "Create database and user"
  RPASS=$(makepasswd --char=10)
  echo  "mysql: mysql://manband:"$RPASS"@"$IP"/manband" >  /var/lib/xgrid/.manband
  echo "s3:" >> /var/lib/xgrid/.manband
  echo "  host: $S3HOST" >> /var/lib/xgrid/.manband
  echo "  port: $S3PORT" >> /var/lib/xgrid/.manband
  echo "  path: $S3PATH" >> /var/lib/xgrid/.manband

  echo "CREATE DATABASE manband;" > /tmp/manband.sql
  echo "CREATE USER 'manband'@'localhost' IDENTIFIED BY '"$RPASS"';" >> /tmp/manband.sql
  echo "GRANT ALL PRIVILEGES ON manband.* TO 'manband'@'localhost';" >> /tmp/manband.sql
  echo "CREATE USER 'manband'@'%' IDENTIFIED BY '"$RPASS"';" >> /tmp/manband.sql
  echo "GRANT ALL PRIVILEGES ON manband.* TO 'manband'@'%';" >> /tmp/manband.sql
  mysql -u root < /tmp/manband.sql

  sed -i "s/modules: Xgrid/modules: Xgrid,XgridManband/" /etc/xgrid/xgrid.yaml
 
fi

if [ "$WORKFLOW" = "wfmaster" ]; then
  echo "Install software"
  gem install manband
  echo "Install web server and workflow manager"
  cd /usr/share/xgrid/manband/
  git clone https://gforge.inria.fr/git/manband/manband.git
  echo "s3:" > ~/.manband
  echo "  host: $S3HOST" >> ~/.manband
  echo "  port: $S3PORT" >> ~/.manband
  echo "  path: $S3PATH" >> ~/.manband
  echo "  workdir: /omaha-beach/manband" >> ~/.manband
  echo "  uploaddir: /omaha-beach/manband/upload" >> ~/.manband
  mkdir -p /omaha-beach/manband/upload

  echo "Start workflow handler"
  export AMQP_URL
  export MYSQL_URL
  cd manband/bin
  ruby -rubygems workflowhandler.rb &
  cd ../..
  cd webband
  rackup -p 4444 -D


fi

if [ "$WORKFLOW" = "wfslave" ]; then
  echo "Install software"
  gem install manband

  echo "Install workflow node"
  cd /usr/share/xgrid/manband/
  git clone https://gforge.inria.fr/git/manband/manband.git
  echo "s3:" > ~/.manband
  echo "  host: $S3HOST" >> ~/.manband
  echo "  port: $S3PORT" >> ~/.manband
  echo "  path: $S3PATH" >> ~/.manband
  echo "  workdir: /omaha-beach/manband" >> ~/.manband
  echo "  uploaddir: /omaha-beach/manband/upload" >> ~/.manband
  mkdir -p /omaha-beach/manband/upload

  echo "Start workflow node"
  export AMQP_URL
  export MYSQL_URL
  cd manband/bin
  ruby -rubygems jobhandler.rb -i $HOSTNAME &

fi
