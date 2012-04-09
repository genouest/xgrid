require 'rubygems'
require 'sinatra/base'
require 'xgridconfig.rb'
require 'AWS'

XgridConfig.adddashboard('SGE','/admin/sge')

class XgridSge < Sinatra::Base

  enable :sessions
  set :static, true
  set :root, File.dirname(__FILE__)

  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

get '/admin/sge' do
  erb :sge
end


end
