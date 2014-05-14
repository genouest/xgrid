#!/bin/bash

# History:
# Fix bug #87: add hadoop.tmp.dir

. /mnt/context.sh

if [ -e  /var/lib/xgrid/ec2.properties ]; then
  . /var/lib/xgrid/ec2.properties
fi


if [ -z $HADOOP ]; then
  # No hadoop requirement, exiting
  echo "Not an hadoop install, exiting..."
  exit 0;
fi

if [ -e /var/lib/xgrid/firstboot ]; then
  echo "First boot, initializing Hadoop"
else
  echo "This is not the first boot, skipping install"
  exit 0;
fi


usermod -a -G hadoop vuser
usermod -a -G hadoop root

echo "Copy templates"
cp /usr/share/hadoop/templates/conf/core-site.xml  /etc/hadoop/
cp /usr/share/hadoop/templates/conf/hdfs-site.xml  /etc/hadoop/
cp /usr/share/hadoop/templates/conf/mapred-site.xml /etc/hadoop/
cp /usr/share/hadoop/templates/conf/mapred-queue-acls.xml /etc/hadoop/

export JAVA_HOME=/usr/lib/jvm/java-6-openjdk-amd64

echo "export JAVA_HOME=/usr/lib/jvm/java-6-openjdk-amd64" >> /etc/hadoop/hadoop-env.sh
. /etc/hadoop/hadoop-env.sh

if [ -z $MASTERIP ]; then
  # Master case, IP  is current IP
  export MASTERIP=$IP
fi

if [ -z $MASTERID ]; then
  # Master case
  export MASTERID=$HOSTNAME
fi

# Manage tmp dirs
cat /usr/share/hadoop/templates/conf/mapred-site.xml  |perl -pe  's/<configuration>/<configuration>\n<property><name>hadoop.tmp.dir<\/name><value>\${MAPRED_TMPDIR}<\/value><\/property>/'   > /usr/share/hadoop/templates/conf/mapred-site.xml.new
mv /usr/share/hadoop/templates/conf/mapred-site.xml.new /usr/share/hadoop/templates/conf/mapred-site.xml
cat /usr/share/hadoop/templates/conf/hdfs-site.xml  |perl -pe  's/<configuration>/<configuration>\n<property><name>hadoop.tmp.dir<\/name><value>\${HDFS_TMPDIR}<\/value><\/property>/'   > /usr/share/hadoop/templates/conf/hdfs-site.xml.new
mv /usr/share/hadoop/templates/conf/hdfs-site.xml.new /usr/share/hadoop/templates/conf/hdfs-site.xml


echo "Setup environment"
export HADOOP_NN_HOST=$MASTERIP
export HADOOP_JT_HOST=$MASTERIP
export HADOOP_NN_DIR=/omaha-beach/hadoop-nn-$MASTERID
export HADOOP_DN_DIR=/omaha-beach/hadoop-dd-$HOSTNAME

export HADOOP_MAPRED_DIR=/omaha-beach/hadoop-tmp/dd-$HOSTNAME

export SECURITY_TYPE=simple
export SECURITY=false
export KERBEROS_REALM=""
export HBASE_USER=""
export HADOOP_HDFS_USER=hdfs
export HADOOP_MR_USER=mapred
export HADOOP_GROUP=hadoop
export HADOOP_DN_ADDR=0.0.0.0:50010
export HADOOP_DN_HTTP_ADDR=0.0.0.0:50075
export DFS_DATANODE_DIR_PERM=755

export TASK_CONTROLLER=org.apache.hadoop.mapred.DefaultTaskController

export MAPRED_TMPDIR=/omaha-beach/hadoop-tmp/mapred-$HOSTNAME
mkdir -p $MAPRED_TMPDIR
chown -R mapred:hadoop $MAPRED_TMPDIR
chmod -R 775 $MAPRED_TMPDIR
export HDFS_TMPDIR=/omaha-beach/hadoop-tmp/hdfs-$HOSTNAME
mkdir -p $HDFS_TMPDIR
chown -R hdfs:hadoop $HDFS_TMPDIR
chmod -R 775 $HDFS_TMPDIR

perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' /usr/share/hadoop/templates/conf/core-site.xml  > /etc/hadoop/core-site.xml
perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' /usr/share/hadoop/templates/conf/hdfs-site.xml  > /etc/hadoop/hdfs-site.xml
perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' /usr/share/hadoop/templates/conf/mapred-site.xml  > /etc/hadoop/mapred-site.xml
perl -p -e 's/\$\{([^}]+)\}/defined $ENV{$1} ? $ENV{$1} : $&/eg' /usr/share/hadoop/templates/conf/mapred-queue-acls.xml  > /etc/hadoop/mapred-queue-acls.xml

# Bind on any interface
sed -i 's/'${IP}':50070/0.0.0.0:50070/g' /etc/hadoop/hdfs-site.xml
sed -i 's/'${IP}':50030/0.0.0.0:50030/g' /etc/hadoop/mapred-site.xml

# Fix hadoop bug, replace superusergroup by supergroup
sed -i 's/dfs.permissions.superusergroup/dfs.permissions.supergroup/g' /etc/hadoop/hdfs-site.xml

echo "" > /etc/hadoop/slaves

# Check if not already set
test=`grep "StrictHostKeyChecking no"  /etc/ssh/ssh_config`
if [ -z "$test" ]; then
  echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
fi

echo "Setup directories"
mkdir -p  /var/lib/hadoop/hdfs/.ssh
mkdir -p  /var/lib/hadoop/mapred/.ssh
mkdir -p /var/log/hadoop/root
chown -R hdfs:hadoop /var/log/hadoop
chmod -R 775 /var/log/hadoop

mkdir -p $HADOOP_MAPRED_DIR
chown -R mapred:hadoop $HADOOP_MAPRED_DIR

if [ "$HADOOP" == "master" ]; then

  # Declare in xgrid config
  sed -i "s/modules: Xgrid/modules: Xgrid,XgridHadoop/" /etc/xgrid/xgrid.yaml

  echo "Hadoop master"
  mkdir -p  /omaha-beach/hadoop-nn-$MASTERID
  chown -R hdfs:hadoop /omaha-beach/hadoop-nn-$MASTERID
  # Generate Master key
  ssh-keygen -t rsa -P '' -f  /var/lib/hadoop/hdfs/.ssh/id_rsa
  cp  /var/lib/hadoop/hdfs/.ssh/*  /var/lib/hadoop/mapred/.ssh/
  chown -R hdfs:hadoop /var/lib/hadoop/hdfs
  chown -R mapred:hadoop /var/lib/hadoop/mapred

  echo "Start master"
  yes Y |/etc/init.d/hadoop-namenode  format
  /etc/init.d/hadoop-namenode  start
  sudo -u hdfs hadoop fs -chown -R hdfs:hadoop /
  sudo -u hdfs hadoop fs -chmod -R 775 /

  /etc/init.d/hadoop-jobtracker  start
fi
if [ "$HADOOP" == "node" ]; then
  echo "Hadoop node"
  mkdir -p /omaha-beach/hadoop-dd-$HOSTNAME
  chown -R hdfs:hadoop /omaha-beach/hadoop-dd-$HOSTNAME
  echo $MASTERKEY >> /var/lib/hadoop/hdfs/.ssh/authorized_keys
  cp  /var/lib/hadoop/hdfs/.ssh/*  /var/lib/hadoop/mapred/.ssh/
  chown -R hdfs:hadoop /var/lib/hadoop/hdfs
  chown -R mapred:hadoop /var/lib/hadoop/mapred
  /etc/init.d/hadoop-datanode start
  /etc/init.d/hadoop-tasktracker start
  # Declare to xgrid master
  ruby /usr/share/xgrid/plugins/hadoop/sendstatus.rb --master $XGRIDMASTER --name $HOSTNAME.$DOMAIN --id $XGRIDID --key $KEY
fi

touch /var/lib/xgrid/hadoop.done
