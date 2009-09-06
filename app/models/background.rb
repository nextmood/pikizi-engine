# this class store the background normalized image, text, etc....

class Background < ActiveRecord::Base

  acts_as_fleximage :image_directory => 'public/images/backgrounds'


  def self.get_or_create_from_auth(feature, product, user, auth_background)
    knowledge_key = feature.knowledge_key
    bgk_key = auth_background.key
    feature_key = feature.key
    user_key = user.key
    type = auth_background.class.to_s
    conditions = ["knowledge_key=? AND background_key=? AND feature_key=? AND author_key=?", knowledge_key, bgk_key, feature_key, user_key]
    puts "conditions #{conditions.inspect}"
    
    if product_key = (product ? product.key : nil)
      conditions.first << " AND product_key=?"
      conditions << product_key
      puts "conditions #{conditions.inspect}"
    else
      conditions.first << " AND product_key IS NULL"
    end
    puts "conditions=#{conditions.inspect}"
    bgk = Background.find(:first, :conditions => conditions)
    # create a new background if no existence
    bgk ||= Background.create(:type => type,
                              :knowledge_key => knowledge_key,
                              :feature_key => feature_key,
                              :product_key => product_key,
                              :background_key => bgk_key,
                              :author_key => user_key)
    bgk.set_value(auth_background)
    bgk.save
    auth_background.local_url = "/backgrounds/#{bgk.id}"
    bgk
  end
  
  def set_value(auth_background) self.data = auth_background.value end

end

class BgkHtml < Background
  # value is html
end

class BgkText < Background
  # value is text
end

class BgkUrl < Background
  # value is url
end

class BgkImage < Background

  # upload the url_image
  def set_value(url_image)
    # value is url_image
    # upload the image (see fleximage)
    self.image_file_url = url_image
    self.data = nil
  end



end

class BgkVideo < Background
  # value is url video  
end