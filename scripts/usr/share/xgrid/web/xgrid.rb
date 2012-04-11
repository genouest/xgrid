require 'rubygems'
require 'sinatra/base'
require 'xgridadmin.rb'
require 'xgridnode.rb'
require 'xgridconfig.rb'
require 'AWS'

class Xgrid < Sinatra::Base

  enable :sessions
  set :static, true
  set :root, File.dirname(__FILE__)

  set :public_folder, File.dirname(__FILE__) + '/public'

  set :password, XgridConfig.adminpwd
  set :baseurl, XgridConfig.baseurl

  set :apikey, nil

before '/admin*' do
   if session[:authenticated]==nil ||  session[:authenticated]==false
     redirect settings.baseurl+"/login"
   end
   if session[:apikey]==nil || session[:apikey]!=settings.apikey
     session[:authenticated]=false
     redirect settings.baseurl+"/login"
   end
end

before '/api/*' do
  if params[:apikey]!=settings.apikey
    erb :apierror
  end
end

get '/' do 
  redirect '/admin'
end

get '/login' do
   if settings.apikey==nil
     key = XgridKey.get(1)
     if key == nil
       key = XgridKey.new
       key.id = 1
       key.value = rand(36**16).to_s(36)
       key.save
       settings.apikey = key.value
     else
       settings.apikey = key.value
     end
   end
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
  @node = XgridNode.get(params[:id])
  erb :node
end

post '/admin/node/delete/:id' do
  node = XgridNode.get(params[:id])
  deletenode(node)
  node.destroy
  redirect settings.baseurl+'/admin'
end

post '/admin/node/delete' do
 # delete all nodes
 nodes = XgridNode.all
 nodes.each do |node|
   deletenode(node)
   node.destroy
 end
 redirect settings.baseurl+'/admin'
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
    redirect settings.baseurl+"/login"
  end
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

def deletenode(node)
  if node.name.empty?
    # Not yet declared, id unknown, skip EC2 removal
    return nil
  end
  ec2keys = XgridEC2.first
  ec2_access_key = ec2keys.ec2key
  ec2_secret_key = ec2keys.ec2pwd
  ec2_secret_key = Digest::SHA1.hexdigest(ec2_secret_key)
  nodename = node.name.split('.')
  vmid = nodename[3,nodename[0].length-1]
  ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => XgridConfig.url, :port => 4567, :use_ssl => false)

  begin
    response = ec2.terminate_instances(
              :instance_id => [ vmid ]
              )
  rescue Exception => e
     return e.message
  end

  return nil
end

end
