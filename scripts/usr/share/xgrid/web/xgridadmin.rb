#!/usr/bin/ruby

class XgridAdmin

  attr :authenticated,true
  attr :login
  attr :password

  def initialize(pwd)
    @authenticated = false
    @login = "admin"
    @password = pwd
  end

  def authenticate(id,pwd)
    if(@login==id && @password==pwd)
      @authenticated = true
    end
    @authenticated
  end

  def authenticated?()
    @authenticated
  end

end

