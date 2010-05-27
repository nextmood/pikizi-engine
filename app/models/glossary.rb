require 'products_filter'
# describe a synonym

class Glossary

  include MongoMapper::Document

  key :constructor, String  # constructor for a Pf filter  (Primary Key, unique)
  key :label, String  # IHM title
  key :extracts, Array, :default => []

  timestamps!


  # unmatched Glossary have only one extract (extracts.size == 1)
  def is_unmatched() constructor.include?("ProductsFilterAnonymous") end


  def merge(glossary_unmatched)
    raise "error" unless !self.is_unmatched and glossary_unmatched.is_unmatched
    update_attributes(:extracts => self.extracts.concat(glossary_unmatched.extracts))
    ProductsFilterAnonymous.all(:constructor => glossary_unmatched.constructor).each do |pf_anonymous|
      pf_anonymous.mutate(constructor)  
    end
    glossary_unmatched.destroy
  end

  # return a new product filter object (no opinion attached)
  # return an ordered (by decreasing confidence) array of glossaries
  def self.resolve(options = {})
    resolve_string = options[:resolve_string];
    resolve_string = nil if resolve_string == ""

    request_options = { :limit => (options[:limit] || 50), :order => "created_at desc" }

    all_glossaries = if resolve_string
      if options[:automatic_adding]
        request_options[:second_chance] = false
        l = db_search(resolve_string, request_options)
        if l.size == 0
          puts "creating new entry for #{resolve_string.inspect}"
          [Glossary.learn([resolve_string], ProductsFilterAnonymous.code_constructor(resolve_string))]
        else
          l
        end
      else
        request_options[:second_chance] = true
        Glossary.db_search(resolve_string, request_options)
      end
    else
      Glossary.all(request_options)
    end
  end

  def self.db_search(resolve_string, request_options={})
    second_chance = request_options.delete(:second_chance)
    also_unmatched = request_options.delete(:also_unmatched)
    list_words_between_quote = resolve_string.scan(/"(.*?)"/)
    list_words_between_quote.flatten!
    resolve_string = resolve_string.gsub(/"(.*?)"/, '')
    list_string = resolve_string.split(' ')
    list_string.collect(&:downcase!)
    list_string.collect(&:strip!)
    list_words = list_string.clone
    list_string.concat(list_words_between_quote)

    l = Glossary.db_search_bis(list_string, request_options)
    l.delete_if(&:is_unmatched) unless also_unmatched


    if second_chance and l.size == 0 and list_words.size > 0
      puts "second_chance=#{second_chance.inspect} #{list_words.size} #{l.size}"
      # the query returns no results, rewrite the query with most likely similar words
      l = Glossary.db_search_bis(Glossary.db_search_ter(list_words), request_options)
      l.delete_if(&:is_unmatched) unless also_unmatched
    end

    # sort the results
    # to be done
    l.sort! {|g1, g2| g1.created_at <=> g2.created_at }
    l

  end

  def self.db_search_bis(list_string, request_options)
    puts ">>>>> db_search_bis looking for: #{list_string.collect(&:inspect).join(",")} options=#{request_options.inspect}"
    request_options[:extracts] = Regexp.new(list_string.collect { |w| "(#{w})" }.join('|'))
    Glossary.all(request_options)
  end

  def self.db_search_ter(list_words, max_nb_result=2)
    list_similar_words = list_words.inject([]) { |l, word| l.concat(word.similar_leveinstein(Glossary.similar_words)) }
    list_similar_words.sort! { |x1, x2| x1.last <=> x2.last }
    list_similar_words.first(max_nb_result).collect(&:first)
  end

  def to_product_filter() eval(constructor) end

  def self.resolve_as_products_filter(resolve_string)
      array_glossaries = resolve(:resolve_string => resolve_string, :automatic_adding => true, :also_unmatched => true)
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


  # return a list of matched glossary for this given unmatched
  def get_proposals
    raise "error should be un-matched" unless is_unmatched
    Glossary.db_search(extracts.first, :second_chance => true, :limit => 10)
  end

  # return a list of similar words
  def self.similar_words
    @@similar_words ||= Glossary.all.inject([]) do |l, glossary|
      unless glossary.is_unmatched
        glossary.extracts.each do |extract|
          words = extract.split(' ')
          words.each(&:strip!)
          words.each(&:downcase!)
          words.each { |word| l << word unless l.include?(word) }
        end
      end
      l
    end
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

