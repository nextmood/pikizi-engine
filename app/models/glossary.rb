require 'products_filter'
#require 'stemmer'
#require 'classifier'

# describe a synonym

class Glossary

  include MongoMapper::Document

  key :constructor, String  # constructor for a Pf filter  (Primary Key, unique)
  def to_product_filter() eval(constructor) end
  
  key :label, String  # IHM title
  key :extracts, Array, :default => []
  key :is_unmatched, Boolean  # unmatched Glossary have only one extract (extracts.size == 1)

  timestamps!


  def merge(glossary_unmatched)
    raise "error" unless !self.is_unmatched and glossary_unmatched.is_unmatched
    update_attributes(:extracts => self.extracts.concat(glossary_unmatched.extracts))
    #Glossary.classifier.train(id, glossary_unmatched.extracts.first)
    ProductsFilterAnonymous.all(:constructor => glossary_unmatched.constructor).each do |pf_anonymous|
      pf_anonymous.mutate(constructor)  
    end
    glossary_unmatched.destroy
  end

  # return a new product filter object (no opinion attached)
  #culd be nil if error
  def self.resolve_as_products_filter(resolve_string)
    # look up for matched and unmatched
    (Glossary.db_search_perfect(resolve_string) || Glossary.learn_unmatch(resolve_string)).to_product_filter
  end

  def self.learn(extracts, constructor, label=nil, is_unmatched=false)
    extracts = [extracts] unless extracts.is_a?(Array)

      g = Glossary.create(:constructor => constructor,
                    :extracts => extracts,
                    :is_unmatched => is_unmatched,
                    :label => label)
      g.update_attributes(:label => (pf = g.to_product_filter; pf.update_labels_debug; pf.display_as)) unless label
      g
  end

  def self.learn_unmatch(extract)
    Glossary.learn(extract, ProductsFilterAnonymous.code_constructor(extract), ProductsFilterAnonymous.build_label(extract), true)
  end

  # return the unique Glossary Entry (matched or unmatched)
  # nil is none
  def self.db_search_perfect(resolve_string, options = {})
    options[:extracts] = resolve_string
    l = Glossary.all(options)
    raise "error match if any should be unique fr ##{resolve_string} ==> #{l.collect(&:inspect)}.join" if l.size > 1
    l.first
  end


=begin
  def self.classifier(recompute=false)
    unless @@classifier and !recompute
      @@classifier = Classifier::Bayes.new.new
      Glossary.all(:is_unmatched => true).each do |glossary|
        glossary.extracts.each { |extract| @@classifier.train(glossary.id, extract) }
      end
    end
    @@classifier
  end
=end


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
    Glossary.delete_all
    Product.all.each { |product|
      Glossary.learn([product.label, product.idurl], ProductByLabel.code_constructor(product, false))
    }
    ProductsByShortcut.shortcuts.each do |shortcut_idurl, shortcut_label|
     Glossary.learn([shortcut_idurl, shortcut_label], ProductsByShortcut.code_constructor(shortcut_idurl))
    end
    true
  end


end

