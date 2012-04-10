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
