#!/usr/bin/ruby

require 'rubygems'
require 'sinatra/base'
require 'xgridconfig.rb'

require 'chef/config'
require 'chef/log'
require 'chef/rest'



# Add class to dashboard routes if set in configuration
if File.exists?( '/etc/xgrid/xgrid.yaml' )
  configdoc = YAML::load( File.open( '/etc/xgrid/xgrid.yaml' ) )
  modules = configdoc['config']['modules'].split(',')
  modules.each do |mod|
   if mod.strip=="XgridCookbook"
      XgridConfig.adddashboard('Cookbooks','/admin/cookbook')
   end
  end
else
  XgridConfig.adddashboard('Cookbooks','/admin/cookbook')
end



# Class XgridCookbook
class XgridCookbook < Sinatra::Base

   enable :sessions
   set :static, true
   set :root, File.dirname(__FILE__)

   set :public_folder, File.dirname(__FILE__) + '/public'
   set :views, File.dirname(__FILE__) + '/views'

   disable :protection

   error do
      'Error occured' + env['sinatra.error'].message
   end


   get '/admin/cookbook' do
     chefsession = XgridChefSession.getinstance
     @list = chefsession.getlist
     erb :cookbook
   end

   get '/admin/cookbook/:name' do
     @cookbook_name = params[:name]
     erb :cookbook_install
   end

   post '/admin/cookbook/install/:name' do
     chefsession = XgridChefSession.getinstance
     @cookbook_name = params[:name]
     @result = chefsession.installcookbook(params[:name])
     erb :cookbook_install
   end
   #post '/admin/cookbook/details_install/:name' do
   #  chefsession = XgridChefSession.getinstance
   #  @cookbook_name = params[:name]
   #  @result = chefsession.getdetailsinstallcookbook(params[:name])
   #  erb :cookbook_install
   #end
end

# Contains CHEF calls
class XgridChefSession

  @instance = nil

  def self.getinstance
    if @instance.nil?

       if !File.exists? '/usr/share/xgrid/web/chef_keys/client.pem'
           # create a new client/node on the Chef server
           command = "/usr/local/bin/chef-client --node-name "+XgridConfig.hostname+".genouest.org --validation_key /usr/share/xgrid/web/chef_keys/chef-validator.pem -S https://"+XgridConfig.chefserver+" -k /usr/share/xgrid/web/chef_keys/client.pem -l info"
           result = `#{command}`

           # write into the xgrid_chef.log the result
           File.open("/var/log/xgrid_chef.log", "a") do |aFile|
	      aFile.write(command)
              aFile.write(result)
           end
       end
      
       # create a new chef session
       @instance = XgridChefSession.new
    
    end

    return @instance

  end


  def initialize
  # initialize the chef user credentials 
     @chef_server_url='https://'+XgridConfig.chefserver
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

	command = "/usr/local/bin/chef-client --node-name #{@client_name} -k #{@signing_key_filename} -S #{@chef_server_url} -o #{cookbook} -l info > /var/log/chef_#{cookbook}_install.log &"
	system("#{command}")

	return "in progress"

  end

 
 #def getdetailsinstallcookbook(cookbook)
  # install the chef cookbook 

	# initialize variable
	#details = String.new

	# read the log file
	#File.open("/var/log/chef_#{cookbook}_install.log", "r").each_line { |line| details << line }	
        
	#return details
	#return details

  #end

end

