require 'products_filter'
# describe a synonym

class Glossary

  include MongoMapper::Document

  key :constructor, String  # constructor for a Pf filter  (Primary Key, unique)
  key :label, String  # IHM title
  key :extracts, Array, :default => []

  timestamps!



  def is_unmatched() constructor.include?("ProductsFilterAnonymous") end

  # return a new product filter object (no opinion attached)
  # return an ordered (by decreasing confidence) array of glossaries
  def self.resolve(options = {})
    resolve_string = options[:resolve_string];
    resolve_string = nil if resolve_string == ""

    request_options = { :limit => (options[:limit] || 50), :order => "created_at DESC" }

    request_options["$where"] = "function() { for (var i = 0; i < this.extracts.length; i++){
                                                if (this.extracts[i].match(/#{resolve_string}/i)) return true
                                              } 
                                              return false;
                                            }" if resolve_string
    all_glossaries = Glossary.all(request_options)

    if resolve_string and options[:automatic_adding] and all_glossaries.size == 0
      puts "creating new entry =#{resolve_string}"
      [Glossary.learn([resolve_string], ProductsFilterAnonymous.code_constructor(resolve_string))]
    else
      all_glossaries
    end
  end

  def to_product_filter() eval(constructor) end

  def self.resolve_as_products_filter(resolve_string)
      array_glossaries = resolve(:resolve_string => resolve_string, :automatic_adding => true)
      raise "Error calling resolve #{resolve_string} returns []" if array_glossaries.size == 0
      array_glossaries.first.to_product_filter
  end

  # learning system
  # return a glossary
  def self.learn(extracts, constructor)
    label = eval(constructor).display_as
    glossary = find_or_create_glossary(constructor, label)
    extracts.each do |extract|
      glossary.extracts << extract unless glossary.extracts.include?(extract)
    end
    glossary.save
    glossary    
  end


  def self.find_glossary(constructor) Glossary.first(:constructor => constructor) end
  def self.find_or_create_glossary(constructor, label)
    find_glossary(constructor) || Glossary.create(:label => label, :constructor => constructor, :extracts => [])
  end




  def self.first_run
    Product.all.each { |product|
      Glossary.learn([product.label, product.idurl], ProductByLabel.code_constructor(product, false))
      Glossary.learn(["#{product.label} similar", "#{product.idurl} similar"], ProductByLabel.code_constructor(product, true))
    }
    ProductsByShortcut.shortcuts.each do |shortcut_idurl, shortcut_label|
     Glossary.learn([shortcut_idurl, shortcut_label], ProductsByShortcut.code_constructor(shortcut_idurl))
    end
    true
  end


end

