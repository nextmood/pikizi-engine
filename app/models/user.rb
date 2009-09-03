require 'pikizi'


class User < ActiveRecord::Base

  def pkz_user    
    @pkz_user ||= Pikizi::User.create_from_xml(key)
  end


  def is_authorized?() promotion_code == "auth" end


  def self.create_from_key(rpx_data={}, key=nil, promotion_code='none')
    new_user = User.create( :rpx_identifier => rpx_data[:identifier],
                            :rpx_name => rpx_data[:name],
                            :rpx_username => rpx_data[:username],
                            :rpx_email => rpx_data[:email],
                            :promotion_code => promotion_code,
                            :key => key)
    new_user.update_attribute(:key, "U#{new_user.id}") unless key
    new_user
  end

end
