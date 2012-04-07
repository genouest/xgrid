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

  def add_to_sge()

  end

  def self.del_from_sge()

  end

  def self.get_sge_stats()

  end

end

class XgridEC2
   include DataMapper::Resource

   property :ec2key, String, :key => true
   property :ec2pwd, String

   def self.add()

   end

   def self.remove()

   end

end

DataMapper.finalize
DataMapper.auto_upgrade!
