#!/usr/bin/ruby

require 'rubygems'
require 'yaml'
require 'AWS'
require 'json'

configdoc = YAML::load( File.open( '/etc/gone/ec2.yaml' ) )

ec2_access_key = configdoc['config']['ec2_access_key']
ec2_secret_key = configdoc['config']['ec2_secret_key']

ec2_url = configdoc['config']['ec2_url']

#user_data = configdoc['config']['user_data']
masterid = ARGV[0]
masterip = ARGV[1]
masterkey = File.open('/var/lib/hadoop/hdfs/.ssh/id_rsa.pub', 'rb') { |f| f.read.chomp }

user_data ="HADOOP=\"node\"\nMASTERIP=\""+masterip+"\"\nMASTERID=\""+masterid+"\"\nMASTERKEY=\""+masterkey+"\"\n"


ec2_secret_key = Digest::SHA1.hexdigest(ec2_secret_key)

ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => ec2_url, :port => 4567, :use_ssl => false)

puts "-- Calling "+ec2_url+" with user "+ec2_access_key
puts "-- Create an image --"
            begin
                response = ec2.run_instances(
                                :image_id       => configdoc['config']['ami_id'],
                                :min_count      => 1,
                                :max_count      => 1,
                                :instance_type  => configdoc['config']['ami_type'],
                                :user_data      => user_data,
                                :base64_encoded => true
                           )
            rescue Exception => e
                puts "Error: "+e.message

            end
