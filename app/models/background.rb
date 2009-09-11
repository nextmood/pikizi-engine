require 'pikizi'

# this class store the background normalized image, text, etc....

class Background < ActiveRecord::Base

  acts_as_fleximage :image_directory => 'public/images/backgrounds'
  image_storage_format :jpg
  invalid_image_message 'format is invalid. You must supply a valid image file.'
  require_image false
  default_image_path 'public/images/default_background.jpg'

  # look up for all background tags and substitute content with db_id
  def self.create_backgrounds_in_db(knowledge_key)
    # in product
    puts "processing products background"
    Pikizi::Product.xml_keys.each do |p_key|
      # parse xml file for background
      puts "parsing product #{p_key} for background tags"
      is_modified = false

      doc = XML::Document.file(Pikizi::Product.filename_data(p_key))
      doc.root.find("//background").each do |node_bgk|
        if toto(node_bgk, :knowledge_key => node_bgk.parent.parent.attributes['key'],
                       :feature_key => node_bgk.parent.attributes['key'],
                       :product_key => p_key)
          is_modified = true
          puts "product #{p_key} saved"
        end
      end
      doc.save(Pikizi::Product.filename_data("test/#{p_key}")) if is_modified
    end

    puts "processing knowledge background"
    is_modified = false
    doc = XML::Document.file(Pikizi::Knowledge.filename_data(knowledge_key))
    doc.root.find("//question").each do |node_question|
      puts "node-question"
      node_question.find("background").each do |node_bgk_question|
        puts "node-bgk-question"

        if toto(node_bgk_question, :knowledge_key => knowledge_key,
                     :question_key => node_bgk_question.parent.attributes['key'])
          is_modified = true
          puts "question #{node_bgk_question.parent.attributes['key']} saved"
        end
      end
      
      node_question.find("choice/background").each do |node_bgk_choice|
        puts "node-bgk-choice"
        if toto(node_bgk_choice, :knowledge_key => knowledge_key,
                   :question_key => node_bgk_choice.parent.parent.attributes['key'],
                   :choice_key => node_bgk_choice.parent.attributes['key'])
          is_modified = true
          puts "choice #{node_bgk_choice.parent.attributes['key']} saved"
        end
      end

    end
    if is_modified
      doc.save(Pikizi::Knowledge.filename_data("test/#{knowledge_key}"))
      puts " knowledge saved"
    else
      puts "no knowledge modification"
    end
  end

  def self.toto(node_bgk, options={})
    db_id = node_bgk.attributes['db_id']
    if db_id and db_id != ""
      false
    else
      bgk_type = node_bgk.attributes['type']
      new_background_db = Pikizi.const_get("Bgk#{bgk_type.capitalize}").new
      new_background_db.knowledge_key = options[:knowledge_key] 
      new_background_db.background_key = node_bgk.attributes['key']
      new_background_db.feature_key = options[:feature_key]
      new_background_db.product_key = options[:product_key]
      new_background_db.question_key = options[:question_key]
      new_background_db.choice_key = options[:choice_key]
      new_background_db.data = node_bgk.content
      unless new_background_db.save
        new_background_db.errors.each { |e| puts e }
        raise "I can't save background #{new_background_db.errors.size } errors (see above)"
      end
      node_bgk.attributes['db_id'] = new_background_db.id.to_s
      node_bgk.content = ""
      true
    end
  end

  def self.import_images() BgkImage.find(:all).each(&:import_image) end

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

# Background; b = BgkImage.find(:all).first; b.import_image
class BgkImage < Background



  def import_image
    puts "1) uploading image data #{data} in background #{id}"

    # modify the url if needed
    url = data
    x = data.split('.')
    prefix = x.last
    tail = x.last(2).first
    if ["jpg", "png", "gif"].include?(prefix)   and !tail.include?("thumbnail")
      x[x.size - 1] = "/thumbnail"
      url = x.join
    end
    puts "2) uploading image url  #{url}"

    begin
      self.image_file_url = url
      self.save
    rescue
      puts "********* impossinle to catch url #{url}"
    end


  end

end

class BgkVideo < Background
  # value is url video  
end