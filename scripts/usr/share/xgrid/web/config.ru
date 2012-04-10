require 'xgrid.rb'
require 'plugins/sge/xgridsge.rb'
#run Xgrid
run Rack::Cascade.new [Xgrid, XgridSge]
