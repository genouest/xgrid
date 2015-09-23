## Introduction

XGrid is an internal tool developed to ease the deployment of tools in the cloud.

It is used to setup Hadoop, SGE or manband workflows environments and can be extended with plugins to get more.

This package is compatible with OpenNebula or cloud-init compatible clouds.

## Package requirements

python-dev

python-pip

fabric

dos2unix

## Building

You can build a .deb package from sources.

`debian/rules clean`

`debian/rules binary`

## Installation

`dpkg -i xgrid_version_all.deb`

`apt-get -f install`

## Start it up

`service xgrid start`

Xgrid is configured to start up on the boot automatically.

## Access

Xgrid is available from your web browser at the following url: http://domain/xgrid

## Plugins

In order to use plugin(s), you have to add some variables in your contextualization (CONTEXT)

### Xgrid web interface

Name          | Value
------------- | -------------
XGRID_PWD     | *yournewxgridpassword*

### Cookbook

Name              | Value
------------------| -----------------
CHEFSERVER        | http://*yourchefserverurl*
CHEFVALIDATIONKEY | *yourchefvalidationkey* 

### Sun Grid Engine

Name           | Value
-------------- | --------------
XGRID_EC2      | *EC2 ip address*
XGRID_EC2_PORT | *EC2 port*
XGRID_AMI      | *id of the image to use*
SGE            | master

 - When a new node is started via the xgrid interface, the software will add EC2 user data:

Name          | Value
------------- | -------------
SGE           | *node*
SGEMASTER     | *IP.of.the.master*
XGRIDID       | *x*
KEY | *xxxxxxxx*

### HADOOP

Name           | Value
-------------- | --------------
XGRID_EC2      | *EC2 ip address*
XGRID_EC2_PORT | *EC2 port*
XGRID_AMI      | *id of the image to use*
HADOOP         | master

## NFS mounts

Name          | Value
------------- | -------------
SHAREDFS      | *IP:/shareddirectory*
DATABANKS     |  *IP:/shareddatabanks*

## Baseurl and password

After boot, /usr/share/xgrid/web/xgridconfig.rb:

- one may need to adapt baseurl parameter depending on deployment to get VM url.

- the password is unique (specified in context variables or generated at instance startup).

## Download

Xgrid packages for Wheezy and Jessie are available for download : http://genocloud.genouest.org/appliances/xgrid_packages/
