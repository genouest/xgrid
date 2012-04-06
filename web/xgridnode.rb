#!/usr/bin/ruby

require 'dm-core'
require 'dm-migrations'

DataMapper.setup( :default, "sqlite3://#{Dir.pwd}/xgrid.db")

class XgridNode
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :status, Integer
  property :info, String

end

class XgridEC2
   include DataMapper::Resource

   property :ec2key, String, :key => true
   property :ec2pwd, String

end

DataMapper.finalize
DataMapper.auto_upgrade!
