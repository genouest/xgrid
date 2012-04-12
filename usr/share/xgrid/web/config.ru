require 'rubygems'

begin
  Gem::Specification::find_by_name("dm-core")
rescue Gem::LoadError
  puts "Missing gem dependencies, exiting..."
  Process.exit
end

require 'xgrid.rb'
require 'plugins/sge/xgridsge.rb'
require 'yaml'


# Read config etc/xgrid/xgrid.yaml
configdoc = YAML::load( File.open( '/etc/xgrid/xgrid.yaml' ) )
modules = configdoc['config']['modules'].split(',')

#run Rack::Cascade.new [Xgrid, XgridSge]
myapp = Rack::Cascade.new []
modules.each do |app|
  myapp << Kernel.const_get(app)
end
run myapp