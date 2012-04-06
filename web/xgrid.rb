require 'sinatra'
require 'xgridadmin.rb'
require 'xgridnode.rb'

enable :sessions

set :password, 'admin'

@@apikey = rand(36**16).to_s(36)

before '/admin*' do
   if session[:authenticated]==nil ||  session[:authenticated]==false
     redirect "/login"
   end
   if session[:apikey]==nil || session[:apikey]!=@@apikey
     session[:authenticated]=false
     redirect "/login"
   end
end

get '/' do 
  "You can go to the <a href=\"admin\">admin</a> section."
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

get '/admin/addnode' do
   node = XgridNode.new
   node.name = "test"
   node.status = 1
   node.save
   redirect "/admin"
end

get '/admin/ec2' do
  @ec2 = XgridEC2.first
  @ec2all = XgridEC2.all
  erb :ec2
end

post '/admin/ec2update' do
  ec2 = XgridEC2.first
  if(ec2==nil)
    ec2 = XgridEC2.new
  end
  if params[:ec2key].empty? || params[:ec2password].empty?
    redirect 'admin/ec2'
  end
  ec2.ec2key = params[:ec2key]
  ec2.ec2pwd = params[:ec2password]
  ec2.save
  redirect 'admin'
end

post '/login' do
  admin = XgridAdmin.new(settings.password)
  admin.authenticate(params[:login],params[:password])
  if admin.authenticated?
    session[:authenticated] = true
    session[:apikey] = @@apikey
    redirect "/admin"
  else
    redirect "/"
  end
end

get '/slave/:id/:vmname/:vmid/:key' do
  if(params[:key]!=apikey)
   erb :apierror 
  end
  "GET: should add slave #{params[:vmname]} using key #{params[:key]}"
end


def nodeready(nodeid,vmname,vmid)
 # TODO get node in db, update status, add to SGE
end

def requestaddnode()
 # TODO create new node, status pending, send EC2 request with node id
end

def requestdelnode()
 # send EC2 request to delete node, remove from database, remove form SGE
end
