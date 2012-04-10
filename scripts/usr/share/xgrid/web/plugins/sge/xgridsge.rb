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

get '/admin/sge' do
  @amis = XgridEC2.getamis
  erb :sge
end

post '/admin/sge' do
  requestnewnode(params[:ami],params[:type])
  redirect '/admin'
end

post '/api/sge/:id' do
  node = XgridNode.find(params[:id])
  node.name = params[:name]
  node.status = 2
  node.save
  addexecnode(params[name])
  "{ \"status\": \"success\" }"
end

error EC2Error do
  'EC2 error occured' + env['sinatra.error'].message
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
  user_data = "SGE=\"node\"\nSGEMASTER=\""+XgridConfig.ip+"\"\nXGRIDID=\""+node.id.to_s+"\"\nKEY=\""+apikey.value+"\"\n"
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
     raise EC2Error, e.message
  end



end


def addexecnode(id)
#qconf -Ae genocloud.exec.tpl
#==
#hostname              EXECHOSTNAME_WITHDOMAIN
#load_scaling          NONE
#complex_values        NONE
#user_lists            NONE
#xuser_lists           NONE
#projects              NONE
#xprojects             NONE
#usage_scaling         NONE
#report_variables      NONE
#==
#qconf -Mhgrp genocloud.hostgroup.tpl
#replace NONE if present, else add hostname
end

end

