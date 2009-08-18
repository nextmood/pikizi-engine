require 'pikizi'


class User < ActiveRecord::Base

  def pkz_user
    @pkz_user ||= Pikizi::User.create_from_xml(key)
  end


  def is_authorized?() rpx_identifier and (true or promotion_code = "BCKPROMO") end

  def self.id_2_key(id) "U#{id}" end
  
end
