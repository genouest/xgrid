#!/usr/bin/ruby

require 'rubygems'
require 'yaml'
require 'AWS'
require 'json'

require 'optparse'
require 'net/http'

options = {}

options[:host] = 'localhost'

optparse = OptionParser.new do|opts|
   opts.on( '-h', '--help', 'Display this screen' ) do
     puts opts
     exit
   end

   options[:ami] = nil
   opts.on( '-i', '--id ID', 'Image AMI id' ) do|id|
     options[:ami] = id
   end

   options[:size] = 'm1.small'
   opts.on( '-s', '--size SIZE', 'm1.small (default), m1.large, m1.xlarge' ) do|size|
     options[:size] = size
   end

   options[:type] = nil
   opts.on( '-t', '--type TYPE', 'sge or hadoop' ) do|type|
     options[:type] = type
   end

   options[:apikey] = nil
   opts.on( '-k', '--key KEY', 'API key in xgrid' ) do|key|
     options[:apikey] = key
   end

   options[:quantity] = nil
   opts.on( '-q', '--quantity NUMBER', 'Number of node' ) do|number|
     options[:quantity] = number
   end

   options[:ec2_access] = nil
   opts.on( '-a', '--ec2access ID', 'EC2 access id' ) do|access|
     options[:ec2_access] = access
   end

   options[:ec2_password] = nil
   opts.on( '-p', '--ec2password PASSWORD', 'EC2 password' ) do|password|
     options[:ec2_password] = password
   end


end

optparse.parse!

puts options

uri = URI('http://'+options[:host]+':4567/api/ec2')
res = Net::HTTP.post_form(uri, 'apikey' => options[:apikey], 'ec2key' => options[:ec2_access], 'ec2password' => options[:ec2_password])


uri = URI('http://'+options[:host]+':4567/api/'+options[:type])
res = Net::HTTP.post_form(uri, 'apikey' => options[:apikey], 'ami' => options[:ami], 'type' => options[:size], 'quantity' => options[:quantity])

