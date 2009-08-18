require 'pikizi'


class User < ActiveRecord::Base

  def pkz_user
    @pkz_user ||= Pikizi::User.create_from_xml(key)
  end

  ## User's find_or_initialize_with_rpx
  # for use with RPX Now gem
  def self.find_or_initialize_with_rpx(data)
    identifier = data["identifier"]

    # For extra safeguard to make sure that the first user (who is an admin, who didn't sign up rpx, isn't returned)
    unless identifier.nil? || identifier.blank?
      u = self.find_by_identifier(identifier)
      if u.nil?
        u = self.new
        u.read_rpx_response(data)
      end
    end

    return u
  end

  def read_rpx_response(user_data)
    #For actual responses, see http://pastie.org/382356
    self.identifier = user_data['identifier']
    self.email = user_data['verifiedEmail'] || user_data['email']
    self.gender = user_data['gender']
    self.birth_date = user_data['birthday']
    self.first_name = user_data['givenName'] || user_data['displayName']
    self.last_name = user_data['familyName']
    self.login = user_data['preferredUsername']
    self.country = user_data['address']['country'] unless user_data['address'].nil?
  end

  def is_authorized?() rpx_identifier and (true or promotion_code = "BCKPROMO") end

end
