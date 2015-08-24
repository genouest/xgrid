## Introduction

This package sets up Sun Grid Engine for Open Nebula or cloud-init compatible
clouds.

## Package requirements

python-dev, python-pip, fabric, dos2unix

## Building

You can build a .deb package from sources.

`debian/rules clean`

`debian/rules binary`

## Installation

`*dpkg -i xgrid__version__all.deb*`

## Plugins

In order to use plugin(s), you have to add some variables in your contextualization (CONTEXT)

# Xgrid web interface

Name          | Value
------------- | -------------
XGRID_PWD     | *yournewxgridpassword*

# Cookbook

Name              | Value
------------------| -----------------
CHEFSERVER        | http://*yourchefserverurl*
CHEFVALIDATIONKEY | *yourchefvalidationkey* 

# Sun Grid Engine

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

# HADOOP

Name           | Value
-------------- | --------------
XGRID_EC2      | *EC2 ip address*
XGRID_EC2_PORT | *EC2 port*
XGRID_AMI      | *id of the image to use*
HADOOP         | master

# NFS mounts

Name          | Value
------------- | -------------
SHAREDFS      | *IP:/shareddirectory*
DATABANKS     |  *IP:/shareddatabanks*

## Possible configuration

After boot, /usr/share/xgrid/web/xgridconfig.rb:

- one may need to adapt baseurl parameter depending on deployment to get VM url.

The password in xgridconfig.rb is unique and generated at instance startup.

# Package requirements

python-dev, python-pip, fabric, dos2unix
