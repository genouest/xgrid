
##
# Config shared with core and plugins
#
class XgridConfig

  # Update to base url
  @@baseurl = ''

  @@ami = ''

  @@instancetypes = [ 'small', 'large', 'xlarge' ]

  @@ip = ''

  @@hostname = ''

  @@url = ''

  @@port = ''

  @@adminpwd = 'admin'

  @@dashboard = Hash.new

  @@apikey = 'admin'

  @@chefserver = ''

  def self.apikey
    @@apikey
  end

  def self.port
    @@port
  end

  def self.url
    @@url
  end

  def self.ip
    @@ip
  end

  def self.setapikey(key)
    @@apikey = key
  end

  def self.baseurl
    @@baseurl
  end

  def self.ami
    @@ami
  end

  def self.instancetypes
    @@instancetypes
  end

  def self.adminpwd
    @@adminpwd
  end

  def self.dashboard
    @@dashboard
  end

  def self.adddashboard(menu,route)
    @@dashboard[ menu ] =  route
  end

  def self.chefserver
    @@chefserver
  end 

  def self.hostname
    @@hostname
  end

end
