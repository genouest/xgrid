#!/bin/bash

echo "Manband plugin"

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


if [ "$WORKFLOW" = "master" ]; then
  echo "Create database and user"
  RPASS=$(makepasswd --char=10)
  echo  "mysql: mysql://manband:"$RPASS"@"$IP"/manband" >  /var/lib/xgrid/.manband
  LASTIP=`echo $IP| cut -d"." -f4`
  echo  "baseurl: http://cloud-"$LASTIP".genouest.org/manband" >> /var/lib/xgrid/.manband
  echo "s3:" >> /var/lib/xgrid/.manband
  echo "  host: $S3HOST" >> /var/lib/xgrid/.manband
  echo "  port: $S3PORT" >> /var/lib/xgrid/.manband
  echo "  path: $S3PATH" >> /var/lib/xgrid/.manband
  echo "workdir: /omaha-beach/manband" >> /var/lib/xgrid/.manband
  echo "uploaddir: /omaha-beach/manband/upload" >> /var/lib/xgrid/.manband
  mkdir -p /omaha-beach/manband/upload

  echo "CREATE DATABASE manband;" > /tmp/manband.sql
  echo "CREATE USER 'manband'@'localhost' IDENTIFIED BY '"$RPASS"';" >> /tmp/manband.sql
  echo "GRANT ALL PRIVILEGES ON manband.* TO 'manband'@'localhost';" >> /tmp/manband.sql
  echo "CREATE USER 'manband'@'%' IDENTIFIED BY '"$RPASS"';" >> /tmp/manband.sql
  echo "GRANT ALL PRIVILEGES ON manband.* TO 'manband'@'%';" >> /tmp/manband.sql
  mysql -u root < /tmp/manband.sql

  sed -i "s/modules: Xgrid/modules: Xgrid,XgridManband/" /etc/xgrid/xgrid.yaml

  # Install RabbitMQ
  echo "Install messaging"
  DEBIAN_FRONTEND='noninteractive' apt-get -y install rabbitmq-server libmysqlclient-dev
  gem install eventmachine --pre
  gem install manband

  rabbitmqctl change_password guest $RPASS
  echo "amqp: amqp://guest:"$RPASS"@"$IP"/" >> /var/lib/xgrid/.manband
  echo "Install workflow manager"

  cp /var/lib/xgrid/.manband /root/.manband

  cd /usr/share/xgrid/
  git clone https://gforge.inria.fr/git/manband/manband.git 
  cd manband/webband
  export MYSQL_URL=mysql://manband:$RPASS@$IP/manband
  export AMQP_URL=amqp://guest:$RPASS@$IP/
  export MANBANDCONF=/root/.manband
  rackup -p 4444 -I . -D

  # edit the welcome apache page
  sed -i "s/<\/div><div class=\"footer\">/<h2>Manband workflows<\/h2><p>You can configure <b>mandband</b> via <a href=\/xgrid>Xgrid<\/a> web application<\/p><\/div><div class=\"footer\">/" /var/www/html/index.html
 
fi

if [ "$WORKFLOW" = "wfmaster" ]; then
  echo "Install software"
  DEBIAN_FRONTEND='noninteractive' apt-get -y install libmysqlclient-dev
  gem install eventmachine --pre
  gem install manband

  echo "s3:" > /root/.manband
  echo "  host: $S3HOST" >> /root/.manband
  echo "  port: $S3PORT" >> /root/.manband
  echo "  path: $S3PATH" >> /root/.manband
  echo "workdir: /omaha-beach/manband" >> /root/.manband
  echo "uploaddir: /omaha-beach/manband/upload" >> /root/.manband

  echo "Start workflow handler"
  export AMQP_URL
  export MYSQL_URL
  cd /usr/share/xgrid
  git clone https://gforge.inria.fr/git/manband/manband.git
  cd manband/manband/bin
  ruby -rubygems workflowhandler.rb -c /root/.manband -d > /var/log/manband.log &

  # Declare to xgrid master
  ruby /usr/share/xgrid/plugins/manband/sendstatus.rb --master $XGRIDMASTER --name $HOSTNAME.$DOMAIN --id $XGRIDID --key $KEY

fi

if [ "$WORKFLOW" = "wfslave" ]; then
  echo "Install software"
  DEBIAN_FRONTEND='noninteractive' apt-get -y install libmysqlclient-dev
  gem install eventmachine --pre
  gem install manband

  echo "Install workflow node"
  cd /usr/share/xgrid
  git clone https://gforge.inria.fr/git/manband/manband.git
  echo "s3:" > /root/.manband
  echo "  host: $S3HOST" >> /root/.manband
  echo "  port: $S3PORT" >> /root/.manband
  echo "  path: $S3PATH" >> /root/.manband
  echo "workdir: /omaha-beach/manband" >> /root/.manband
  echo "uploaddir: /omaha-beach/manband/upload" >> /root/.manband
  mkdir -p /omaha-beach/manband/upload

  echo "Start workflow node"
  export AMQP_URL
  export MYSQL_URL
  cd manband/manband/bin
  ruby -rubygems jobhandler.rb -i $HOSTNAME -c /root/.manband > /var/log/manband.log &

  # Declare to xgrid master
  ruby /usr/share/xgrid/plugins/manband/sendstatus.rb --master $XGRIDMASTER --name $HOSTNAME.$DOMAIN --id $XGRIDID --key $KEY

fi

touch /var/lib/xgrid/manband.done
