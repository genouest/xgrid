require 'rubygems'
require 'sinatra/base'
require 'xgridconfig.rb'
require 'xgridnode.rb'
require 'AWS'
require 'tempfile'
require 'time'

# Add class to dashboard routes if set in configuration
if File.exists?( '/etc/xgrid/xgrid.yaml' )
  configdoc = YAML::load( File.open( '/etc/xgrid/xgrid.yaml' ) )
  modules = configdoc['config']['modules'].split(',')
  modules.each do |mod|
    if mod.strip=="XgridSge"
      XgridConfig.adddashboard('SGE','/admin/sge')
    end
  end
else
  XgridConfig.adddashboard('SGE','/admin/sge')
end

# Initialize slot allocation
slot = XgridPlugin.get('sge.slots')
if slot==nil
  slot = XgridPlugin.new
  slot.id = 'sge.slots'
  slot.value = 1
  slot.save
end


class XgridSge < Sinatra::Base

  enable :sessions
  set :static, true
  set :root, File.dirname(__FILE__)

  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

  disable :protection

error do
  '<h1>Error occured</h1><p>' + env['sinatra.error'].message + '</p><p>Please check your <a href="'+XgridConfig.baseurl+'/admin/ec2">EC2 access</a></p>'
end


get '/admin/sge' do
  @amis = XgridEC2.getamis
  if @amis==nil
    redirect XgridConfig.baseurl+'/admin/ec2'
  end
  @qstat= `qstat -u '*'`
  #@qstat.gsub!("\n","<br/>")
  @slots = XgridPlugin.get('sge.slots').value
  erb :sge
end

post '/admin/sge' do
  1.upto(params[:quantity].to_i) do
     err = requestnewnode(params[:ami],params[:type])
     if err!=nil
       @error = err
       erb :error
     end
  end
  redirect XgridConfig.baseurl+'/admin'
end

post '/api/sge' do
  1.upto(params[:quantity].to_i) do
     err = requestnewnode(params[:ami],params[:type])
     if err!=nil
       raise 500
     end
  end
  "{ \"status\": \"success\" }"
end

post '/api/sge/:id' do
  node = XgridNode.get(params[:id])
  node.name = params[:name]
  node.status = 2
  node.save
  addexecnode(params[:name])
  "{ \"status\": \"success\" }"
end

# Update queue slots allocation
post '/admin/sge/slots' do
  slots = XgridPlugin.get('sge.slots')
  slots.value = params[:slots]
  slots.save
  updateSlotAllocation(params[:slots])
  redirect XgridConfig.baseurl+'/admin/sge'
end

post '/admin/sge/fabric' do
  fabricnode(params[:script], params[:localhost])
  redirect XgridConfig.baseurl+'/admin/sge'
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

  ssh_pub_key = ""
  if File.exists?("/root/.ssh/id_rsa.pub")
    file = File.open("/root/.ssh/id_rsa.pub", "rb")
    ssh_pub_key = "\nXGRID_ROOT_SSHKEY=\""+file.read.gsub(/\r/,"").gsub(/\n/,"").strip+"\""
  end

  ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => XgridConfig.url, :port => XgridConfig.port.to_i, :use_ssl => false)
  apikey = XgridConfig.apikey
  user_data = "SGE=\"node\"\nSGEMASTER=\""+XgridConfig.ip+"\"\nXGRIDID=\""+node.id.to_s+"\"\nKEY=\""+apikey+"\"\nXGRIDMASTER=\""+XgridConfig.ip+"\"\n"+ssh_pub_key
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

##
# Add host as an execution host
#
def addexecnode(name)
  cur = Time.now.to_i
  system("sed -e 's/\$\{EXECHOSTNAME\}/"+name+"/' /usr/share/xgrid/plugins/sge/templates/genocloud.exec.tpl > /tmp/genocloud.exec."+cur.to_s)
  system("qconf -Ae /tmp/genocloud.exec."+cur.to_s)
  updateexeclist()
end

##
# Update host group, add all nodes with status=2
#
def updateexeclist
  nodes = XgridNode.all(:status => 2)
  execlist = ''
  nodes.each do |node|
    execlist+= node.name+" "
  end
  cur = Time.now.to_i
  system("sed -e 's/NONE/"+execlist+"/' /usr/share/xgrid/plugins/sge/templates/genocloud.hostgroup.tpl > /tmp/genocloud.hostgroup."+cur.to_s)
  system ("qconf  -Mhgrp /tmp/genocloud.hostgroup."+cur.to_s)
end

##
# Update the queue with selected default allocation
#
def updateSlotAllocation(slots)
  cur = Time.now.to_i
  system("sed -e 's/slots                 1/slots                 "+slots+"/' /usr/share/xgrid/plugins/sge/templates/genocloud.queue.tpl > /tmp/genocloud.queue."+cur.to_s)
  system ("qconf  -Mq /tmp/genocloud.queue."+cur.to_s)

end


def fabricnode(script, localhost)
  nodes = XgridNode.all(:status => 2)
  tmpscript = '/tmp/script'+Time.now.to_i.to_s+'.sh'
  tmpfabric = '/tmp/fab'+Time.now.to_i.to_s+'.py'
  File.open(tmpscript, 'w', 0755) { |file| file.write(script) }
  if localhost == "true"
	  nodelist = [ "localhost" ]
  else
	  nodelist = []
  end
  nodes.each do |node|
    #fab command -i /root/.ssh/id_rsa -f tmpfabric
    nodelist.push(node.name)
  end
  nodelist = nodelist.map { |s| "'#{s}'" }.join(',')
  File.open(tmpfabric, 'w', 0755) { |tmpfile|
    tmpfile.write("#!/usr/bin/env python\n")
    tmpfile.write("from fabric.api import *\n")
    tmpfile.write("env.hosts = ["+nodelist+"]\n")
    tmpfile.write("env.user = 'root'\n")
    tmpfile.write("env.warn_only = True\n")
    tmpfile.write("\n")
    tmpfile.write("def command():\n")
    tmpfile.write("    put(\""+tmpscript+"\", \"/tmp/script.sh\", mode=0755)\n")
    tmpfile.write("    run(\"/tmp/script.sh\")\n")
  }
  system("dos2unix "+tmpscript)
  system("fab command -i /root/.ssh/id_rsa -f "+tmpfabric+" >> /var/log/xgrid_fabric.log &")
end


end

