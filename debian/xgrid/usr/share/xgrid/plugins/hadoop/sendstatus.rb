#!/usr/bin/ruby

require 'optparse'
require 'net/http'

options = {}

optparse = OptionParser.new do|opts|
   opts.on( '-h', '--help', 'Display this screen' ) do
     puts opts
     exit
   end
   options[:master] = nil
   opts.on( '-m', '--master MASTER', 'Master ip address' ) do|master|
     options[:master] = master
   end

   options[:id] = nil
   opts.on( '-i', '--id ID', 'Image id in xgrid' ) do|id|
     options[:id] = id
   end

   options[:apikey] = nil
   opts.on( '-k', '--key KEY', 'API key in xgrid' ) do|key|
     options[:apikey] = key
   end

   options[:name] = nil
   opts.on( '-n', '--name NAME', 'Name of current instance' ) do|name|
     options[:name] = name
   end

end

optparse.parse!

uri = URI('http://'+options[:master]+':4567/api/node/'+options[:id])
res = Net::HTTP.post_form(uri, 'apikey' => options[:apikey], 'name' => options[:name])
puts res.body

