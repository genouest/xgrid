require 'rubygems'
require 'sinatra/base'
require 'xgridadmin.rb'
require 'xgridnode.rb'
require 'AWS'

class Xgrid < Sinatra::Base

  enable :sessions
  set :static, true
  set :root, File.dirname(__FILE__)

  set :public_folder, File.dirname(__FILE__) + '/public'

  set :password, 'admin'
  set :baseurl, ''

  set :apikey, rand(36**16).to_s(36)

before '/admin*' do
   if session[:authenticated]==nil ||  session[:authenticated]==false
     redirect settings.baseurl+"/login"
   end
   if session[:apikey]==nil || session[:apikey]!=settings.apikey
     session[:authenticated]=false
     redirect settings.baseurl+"/login"
   end
end

get '/' do 
  "You can go to the <a href=\""+settings.baseurl+"admin\">admin</a> section."
end

get '/login' do
 erb :login
end

get '/admin' do
   @userapi = session[:apikey]
   @nodes = XgridNode.all
   @ec2 = XgridEC2.all
   erb :admin
end


post '/admin/node' do
  if(params[:apikey]!=settings.apikey)
   erb :apierror
  end
  node = XgridNode.new
  node.name = "test"
  node.status = 1
  node.save
  redirect settings.baseurl+"/admin"
end

#patch 'api/node/:id' do
  # Update node
#end

get '/admin/node/:id' do
  @node = XgridNode.find(params[:id])
  erb :node
end

delete '/admin/node/:id' do
 # delete one node
end

delete '/admin/nodes' do
 # delete all nodes
end

get '/admin/ec2' do
  @ec2 = XgridEC2.first
  @ec2all = XgridEC2.all
  erb :ec2
end

post '/admin/ec2' do
  ec2 = XgridEC2.first
  if(ec2==nil)
    ec2 = XgridEC2.new
  end
  if params[:ec2key].empty? || params[:ec2password].empty?
    redirect settings.baseurl+'/admin/ec2'
  end
  ec2.ec2key = params[:ec2key]
  ec2.ec2pwd = params[:ec2password]
  ec2.save
  redirect settings.baseurl+'/admin'
end

post '/login' do
  admin = XgridAdmin.new(settings.password)
  admin.authenticate(params[:login],params[:password])
  if admin.authenticated?
    session[:authenticated] = true
    session[:apikey] = settings.apikey
    redirect settings.baseurl+"/admin"
  else
    redirect settings.baseurl+"/"
  end
end


def nodeready(nodeid,vmname,vmid)
 # TODO get node in db, update status, add to SGE
end

def requestaddnode()
 # TODO create new node, status pending, send EC2 request with node id
 # ec2_secret_key = Digest::SHA1.hexdigest(ec2_secret_key)
 # ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => ec2_url, :port => 4567, :use_ssl => false)
 # begin
 #   response = ec2.run_instances(
 #             :image_id       => configdoc['config']['ami_id'],
 #             :min_count      => 1,
 #             :max_count      => 1,
 #             :instance_type  => configdoc['config']['ami_type'],
 #             :user_data      => user_data,
 #             :base64_encoded => true
 #             )
 # rescue Exception => e
 #   puts "Error: "+e.message
 # end

end

def requestdelnode()
 # send EC2 request to delete node, remove from database, remove form SGE
end

end
