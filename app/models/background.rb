# this class store the background normalized image, text, etc....

class Background < ActiveRecord::Base

  #acts_as_fleximage :image_directory => 'public/images/backgrounds'

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
    puts "condirtions=#{conditions.inspect}"
    bgk = Background.find(:first, :conditions => conditions)
    # create a new background if no existence
    bgk ||= Background.create(:type => type,
                              :knowledge_key => knowledge_key,
                              :feature_key => feature_key,
                              :product_key => product_key,
                              :background_key => bgk_key,
                              :author_key => user_key)
    bgk.set_value(auth_background.value)
    bgk.save
    bgk
  end
  
  def set_value(value) self.data = value end

end

class BgkHtml < Background
  def set_value(html)
    self.data = html
  end
end

class BgkText < Background
  def set_value(text)
    self.data = text
  end
end

class BgkUrl < Background
  def set_value(url)
    self.data = url
  end
end

class BgkImage < Background
  def set_value(url_image)
    self.data = url_image
  end
end

class BgkVideo < Background
  def set_value(url_video)
    self.data = url_video
  end
end