#!/bin/bash

# remove xgrid log if it's already launched
if [ -e /var/log/xgrid.log ]; then

	# remove xgrid log files
	rm /var/log/xgrid.log
	rm -r /var/log/xgrid
	rm /var/log/chef*

	# remove xgrid plugin section
	sed -i "s/modules: .*/modules: Xgrid/" /etc/xgrid/xgrid.yaml

	# remove xgrid files
	rm /var/lib/xgrid/context.sh
	rm /var/lib/xgrid/manband.done
	rm /var/lib/xgrid/sge.done

	# remove chef client.pem
	rm /usr/share/xgrid/web/chef_keys/client.pem

	# remove mounts
	sed -i '/\/var\/lib\/xgrid/d' /etc/exports
	sed -i '/\/opt/d' /etc/exports
	sed -i '/\/omaha-beach/d' /etc/fstab
	sed -i '/\/db/d' /etc/fstab

	umount -f -l /omaha-beach
	umount -f -l /db

	# remove ssh key
	rm /root/.ssh/id_rsa
        rm /root/.ssh/id_rsa.pub

	# remove chef validation key
	if [ -e /usr/share/xgrid/chef_keys/chef-validator.pem ]; then
		rm /usr/share/xgrid/chef_keys/chef-validator.pem
	fi

	# remove sge tools & configurations
	DEBIAN_FRONTEND='noninteractive' apt-get --purge -y remove gridengine-master gridengine-client gridengine-drmaa1.0 gridengine-exec
	PURGE_CONF='noninteractive' apt-get purge -y gridengine-*

	# create the firstboot file to init xgrid
        touch /var/lib/xgrid/firstboot

fi

# launch xgrid
/usr/share/xgrid/init.sh
