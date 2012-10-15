
##
# Config shared with core and plugins
#
class XgridConfig

  # Update to base url
  @@baseurl = ''

  @@instancetypes = [ 'small', 'large', 'xlarge' ]

  @@ip = ''

  @@url = '192.168.2.91'

  @@adminpwd = 'admin'

  @@dashboard = Hash.new

  def self.apikey
    @@apikey
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

end
