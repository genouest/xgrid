require 'rubygems'
require 'sinatra/base'
require 'xgridconfig.rb'
require 'xgridnode.rb'
require 'AWS'

XgridConfig.adddashboard('SGE','/admin/sge')

class XgridSge < Sinatra::Base

  enable :sessions
  set :static, true
  set :root, File.dirname(__FILE__)

  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

error do
  'Error occured' + env['sinatra.error'].message
end


get '/admin/sge' do
  @amis = XgridEC2.getamis
  if @amis==nil
    redirect XgridConfig.baseurl+'/admin/ec2'
  end
  @qstat= `qstat -u '*'`
  @qstat.gsub!("\n","<br/>")
  erb :sge
end

post '/admin/sge' do
  1.upto(params[:quantity].to_i) do
     err = requestnewnode(params[:ami],params[:type])
     if err!=nil
       raise ec2error, err
     end
  end
  redirect XgridConfig.baseurl+'/admin'
end

post '/api/sge/:id' do
  node = XgridNode.get(params[:id])
  node.name = params[:name]
  node.status = 2
  node.save
  addexecnode(params[:name])
  "{ \"status\": \"success\" }"
end

def requestnewnode(ami,type)
  ec2keys = XgridEC2.first
  ec2_access_key = ec2keys.ec2key
  ec2_secret_key = ec2keys.ec2pwd
  ec2_secret_key = Digest::SHA1.hexdigest(ec2_secret_key)

  node = XgridNode.new
  node.name = ""
  node.status = 1
  node.save

  ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => XgridConfig.url, :port => 4567, :use_ssl => false)
  apikey = XgridKey.get(1)
  user_data = "SGE=\"node\"\nSGEMASTER=\""+XgridConfig.ip+"\"\nXGRIDID=\""+node.id.to_s+"\"\nKEY=\""+apikey.value+"\"\nXGRIDMASTER=\""+XgridConfig.ip+"\"\n"
  begin
    response = ec2.run_instances(
              :image_id       => ami,
              :min_count      => 1,
              :max_count      => 1,
              :instance_type  => type,
              :user_data      => user_data,
              :base64_encoded => true
              )
  rescue Exception => e
     return e.message
  end

  return nil

end


def addexecnode(name)
  cur = Time.now.to_i
  system("sed -e 's/\$\{EXECHOSTNAME\}/"+name+"/' /usr/share/xgrid/templates/genocloud.exec.tpl > /tmp/genocloud.exec."+cur.to_s)
  system("qconf -Ae /tmp/genocloud.exec."+cur.to_s)
  updateexeclist()
end

def updateexeclist
  nodes = XgridNode.all(:status => 2)
  execlist = ''
  nodes.each do |node|
    execlist+= node.name+" "
  end
  cur = Time.now.to_i
  system("sed -e 's/NONE/"+execlist+"/' /usr/share/xgrid/templates/genocloud.hostgroup.tpl > /tmp/genocloud.hostgroup."+cur.to_s)
  system ("qconf  -Mhgrp /tmp/genocloud.hostgroup."+cur.to_s)
end

end
