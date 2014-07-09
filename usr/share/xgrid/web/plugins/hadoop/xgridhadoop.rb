require 'rubygems'
require 'sinatra/base'
require 'xgridconfig.rb'
require 'xgridnode.rb'
require 'AWS'

# Add class to dashboard routes if set in configuration
if File.exists?( '/etc/xgrid/xgrid.yaml' )
  configdoc = YAML::load( File.open( '/etc/xgrid/xgrid.yaml' ) )
  modules = configdoc['config']['modules'].split(',')
  modules.each do |mod|
    if mod.strip=="XgridHadoop"
      XgridConfig.adddashboard('Hadoop','/admin/hadoop')
    end
  end
else
  XgridConfig.adddashboard('Hadoop','/admin/hadoop')
end


class XgridHadoop < Sinatra::Base

  enable :sessions
  set :static, true
  set :root, File.dirname(__FILE__)

  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

  disable :protection

error do
  'Error occured' + env['sinatra.error'].message
end


get '/admin/hadoop' do
  @amis = XgridEC2.getamis
  if @amis==nil
    redirect XgridConfig.baseurl+'/admin/ec2'
  end
  erb :hadoop
end

post '/admin/hadoop' do
  1.upto(params[:quantity].to_i) do
     err = requestnewnode(params[:ami],params[:type])
     if err!=nil
       @error = err 
       erb :error
     end
  end
  redirect XgridConfig.baseurl+'/admin'
end

post '/api/hadoop' do
  1.upto(params[:quantity].to_i) do
     err = requestnewnode(params[:ami],params[:type])
     if err!=nil
       raise 500
     end
  end
  "{ \"status\": \"success\" }"
end

##
# Sends an EC2 request for a new node
#
def requestnewnode(ami,type)
  ec2keys = XgridEC2.first
  ec2_access_key = ec2keys.ec2key
  ec2_secret_key = ec2keys.ec2pwd
  #ec2_secret_key = Digest::SHA1.hexdigest(ec2_secret_key)

  node = XgridNode.new
  node.name = ""
  node.status = 1
  node.save

  masterid = `hostname`.strip
  masterip = XgridConfig.ip
  masterkey = File.open('/var/lib/hadoop/hdfs/.ssh/id_rsa.pub', 'rb') { |f| f.read.chomp }
  user_data ="HADOOP=\"node\"\nMASTERIP=\""+masterip+"\"\nMASTERID=\""+masterid+"\"\nMASTERKEY=\""+masterkey+"\"\n"
  apikey = XgridConfig.apikey
  user_data += "XGRIDID=\""+node.id.to_s+"\"\nKEY=\""+apikey+"\"\nXGRIDMASTER=\""+XgridConfig.ip+"\"\n"

  ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => XgridConfig.url, :port => XgridConfig.port.to_i, :use_ssl => false)

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


end

