#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'base64'

data = Base64.decode64(ARGV[0])

outfile = File.open("/var/lib/xgrid/ec2.properties", 'w')
outfile.write(data)
outfile.close()

