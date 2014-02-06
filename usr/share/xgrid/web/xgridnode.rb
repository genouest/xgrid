#!/usr/bin/ruby

require 'dm-core'
require 'dm-migrations'

DataMapper.setup( :default, "sqlite3://#{Dir.pwd}/xgrid.db")

# Contains 1 record per node with its current status
class XgridNode
  include DataMapper::Resource

  property :id, Serial
  property :name, String
  property :status, Integer
  property :info, String

end

# Contains EC2 key and password
class XgridEC2
   include DataMapper::Resource

   property :ec2key, String, :key => true
   property :ec2pwd, String

  def self.getamis
    ec2keys = XgridEC2.first
    if ec2keys == nil
      return nil
    end
    ec2_access_key = ec2keys.ec2key
    ec2_secret_key = ec2keys.ec2pwd
    ec2_secret_key = Digest::SHA1.hexdigest(ec2_secret_key)
    ec2 = AWS::EC2::Base.new(:access_key_id => ec2_access_key, :secret_access_key => ec2_secret_key, :server => XgridConfig.url, :port => XgridConfig.port.to_i, :use_ssl => false)
    return ec2.describe_images.imagesSet.item
  end


end

# contains a single key used for APIs
class XgridKey
   include DataMapper::Resource

   property :id, Integer, :key => true
   property :value, String
end

# Table with key/value for plugins
class XgridPlugin
  include DataMapper::Resource

  property :id, String, :key =>  true
  property :value, String
end


DataMapper.finalize
DataMapper.auto_upgrade!
