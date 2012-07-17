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
    if mod.strip=="XgridManband"
      XgridConfig.adddashboard('ManBand','/admin/manband')
    end
  end
else
  XgridConfig.adddashboard('ManBand','/admin/manband')
end

# Set up config the first time
manbandmysql = XgridPlugin.get('manband.mysql')
if manbandmysql == nil
  if File.exists?( '/var/lib/xgrid/.manband' )
    configdoc = YAML::load( File.open( '/var/lib/xgrid/.manband' ) )

    manbandconfig  = XgridPlugin.new
    manbandconfig.id = 'manband.mysql'
    manbandconfig.value = configdoc['mysql']
    manbandconfig.save

    manbandconfig  = XgridPlugin.new
    manbandconfig.id = 'manband.amqp'
    manbandconfig.value = configdoc['amqp']
    manbandconfig.save

    manbandconfig  = XgridPlugin.new
    manbandconfig.id = 'manband.s3host'
    manbandconfig.value = configdoc['s3']['host']
    manbandconfig.save

    manbandconfig  = XgridPlugin.new
    manbandconfig.id = 'manband.s3port'
    manbandconfig.value = configdoc['s3']['port'].to_i
    manbandconfig.save

    manbandconfig  = XgridPlugin.new
    manbandconfig.id = 'manband.s3path'
    manbandconfig.value = configdoc['s3']['path']
    manbandconfig.save

  end
end


class XgridManband < Sinatra::Base

  enable :sessions
  set :static, true
  set :root, File.dirname(__FILE__)

  disable :protection

  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

error do
  'Error occured' + env['sinatra.error'].message
end


get '/admin/manband' do
  @amis = XgridEC2.getamis
  if @amis==nil
    redirect XgridConfig.baseurl+'/admin/ec2'
  end
  @wfmysql = XgridPlugin.get('manband.mysql').value
  @wfamqp = XgridPlugin.get('manband.amqp').value
  @wfs3host = XgridPlugin.get('manband.s3host').value
  @wfs3port = XgridPlugin.get('manband.s3port').value
  @wfs3path = XgridPlugin.get('manband.s3path').value
  erb :manband
end

post '/admin/manband' do
  1.upto(params[:quantity].to_i) do
     err = requestnewnode(params[:ami],params[:type],params[:kind])
     if err!=nil
       @error = err 
       erb :error
     end
  end
  redirect XgridConfig.baseurl+'/admin'
end

post '/admin/manband/config' do
  wfconfig_mysql = XgridPlugin.get('manband.mysql')
  wfconfig_mysql.value = params[:manband_mysql]
  wfconfig_mysql.save
  wfconfig_amqp = XgridPlugin.get('manband.amqp')
  wfconfig_amqp.value = params[:manband_amqp]
  wfconfig_amqp.save
  wfconfig_s3host = XgridPlugin.get('manband.s3host')
  wfconfig_s3host.value = params[:manband_s3host]
  wfconfig_s3host.save
  wfconfig_s3port = XgridPlugin.get('manband.s3port')
  wfconfig_s3port.value = params[:manband_s3port].to_i
  wfconfig_s3port.save
  wfconfig_s3path = XgridPlugin.get('manband.s3path')
  wfconfig_s3path.value = params[:manband_s3path]
  wfconfig_s3path.save
  redirect XgridConfig.baseurl+'/admin/manband'
end


##
# Sends an EC2 request for a new node
# Kind: wfmaster for workflow manager, wfslave for workflow node
#
def requestnewnode(ami,type,kind)
  ec2keys = XgridEC2.first
  ec2_access_key = ec2keys.ec2key
  ec2_secret_key = ec2keys.ec2pwd
  ec2_secret_key = Digest::SHA1.hexdigest(ec2_secret_key)

  node = XgridNode.new
  node.name = ""
  node.status = 1
  node.save

  wfmysql = XgridPlugin.get('manband.mysql').value
  wfamqp = XgridPlugin.get('manband.amqp').value
  wfs3host = XgridPlugin.get('manband.s3host').value
  wfs3port = XgridPlugin.get('manband.s3port').value
  wfs3path = XgridPlugin.get('manband.s3path').value

  user_data = "WORKFLOW=\""+kind+"\"\n"
  user_data +="AMQP_URL=\""+wfamqp+"\"\n"
  user_data +="MYSQL_URL=\""+wfmysql+"\"\n"
  user_data +="S3HOST=\""+wfs3host+"\"\n"
  user_data +="S3PORT=\""+wfs3port.to_s+"\"\n"
  user_data +="S3PATH=\""+wfs3path+"\"\n"

  apikey = XgridKey.get(1)
  user_data += "XGRIDID=\""+node.id.to_s+"\"\nKEY=\""+apikey.value+"\"\nXGRIDMASTER=\""+XgridConfig.ip+"\"\n"

  ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => XgridConfig.url, :port => 4567, :use_ssl => false)

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
     node.destroy
     return e.message
  end

  node.update(:info => response["instancesSet"]["item"][0]["instanceId"]+' - '+kind)

  return nil

end


end

