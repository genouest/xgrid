#!/usr/bin/ruby

require 'rubygems'
require 'sinatra/base'
require 'xgridconfig.rb'

require 'chef/config'
require 'chef/log'
require 'chef/rest'

# Contains EC2 key and password
class XgridChefSession

  @instance = nil

  def self.getinstance
    if @instance.nil?

       # create a new client/node on the Chef server
       command = "/usr/local/bin/chef-client --validation_key /usr/share/xgrid/web/chef_keys/chef-validator.pem -S  http://"+XgridConfig.chefserver+" -k /usr/share/xgrid/web/chef_keys/client.pem -l info"
       result = `#{command}`

       # write into the xgrid_chef.log the result
       File.open("/var/log/xgrid_chef.log", "a") do |aFile|
              aFile.write(result)
       end

       # create a new chef session
       @instance = XgridChefSession.new
    end

    return @instance

  end


  def initialize
  # initialize the chef user credentials 
     @chef_server_url='http://'+XgridConfig.chefserver
     @client_name = XgridConfig.hostname+'.genouest.org'
     @signing_key_filename = '/usr/share/xgrid/web/chef_keys/client.pem'
  end

  def getlist
  # generate the cookbook list from the CHEF server

	# create a chef rest object
	rest = Chef::REST.new(@chef_server_url, @client_name, @signing_key_filename)

	# generate the cookbooks list
	cookbooks = rest.get_rest("/cookbooks")

	# put cookbooks in a tab
	cookbook_list = []
	cookbooks.keys.each do |name|
		cookbook_list << name
        end


    return cookbook_list
  end

  def installcookbook(cookbook)
  # install the chef cookbook 

	command = "/usr/local/bin/chef-client -k #{@signing_key_filename} -S #{@chef_server_url} -o #{cookbook} -l info"
	result = `#{command}`
	
	# write in the xgrid_chef.log
	File.open("/var/log/xgrid_chef.log", "a") do |aFile|
		aFile.write(result)
	end

	return result.to_s
  end

end


