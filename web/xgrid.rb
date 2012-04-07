require 'sinatra'
require 'xgridadmin.rb'
require 'xgridnode.rb'
require 'AWS'

enable :sessions

set :password, 'admin'
set :baseurl, ''

@@apikey = rand(36**16).to_s(36)

before '/admin*' do
   if session[:authenticated]==nil ||  session[:authenticated]==false
     redirect settings.baseurl+"/login"
   end
   if session[:apikey]==nil || session[:apikey]!=@@apikey
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


# TODO manage dual route admin/node api/node
post '/admin/node' do
  if(params[:apikey]!=@@apikey)
   erb :apierror
  end
  node = XgridNode.new
  node.name = "test"
  node.status = 1
  node.save
  redirect settings.baseurl+"/admin"
end


get '/admin/node/:id' do
  # TODO search with id and show info
  #node = XgridNode.find(:id => params[:id])
  #node.id
  "info from node..."
end

#TODO add del /admin/node/:id
#TODO add del/admin/nodes

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
    session[:apikey] = @@apikey
    redirect settings.baseurl+"/admin"
  else
    redirect settings.baseurl+"/"
  end
end

put '/api/node/:id' do
  # TODO update node status and add to SGE
end

get '/slave/:id/:vmname/:vmid/:key' do
  if(params[:key]!=@@apikey)
   erb :apierror 
  end
  "GET: should add slave #{params[:vmname]} using key #{params[:key]}"
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
