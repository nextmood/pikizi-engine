require 'products_filter'
# describe a synonym

class Glossary


  include MongoMapper::Document

  key :extract, String
  key :constructor, String
  key :label, String


  # -----------------------------------------------------------------
  # state machine


  state_machine :initial => :unmatched do

    state :unmatched

    state :matched

    event :match do
      transition all => :matched
    end

  end

  def self.list_states() Glossary.state_machines[:state].states.collect { |s| [s.name.to_s, Glossary.state_datas[s.name.to_s]] } end

  # label of state for UI
  def self.state_datas() { "unmatched" => { :label => "un-matched", :color => "orchid" },
                           "matched" => { :label => "matched", :color => "lightblue" } } end
  def state_label() Glossary.state_datas[state.to_s][:label] end
  def state_color() Glossary.state_datas[state.to_s][:color] end

  # -----------------------------------------------------------------


  # return a new product filter object (no opinion attached)
  # return an ordered array of { :label => , :constructor, :glossaries => }
  def self.resolve(options = {})
    request_options = { :limit => (options[:limit] || 50), :state => (options[:states] || Glossary.list_states.collect(&:first)) }
    if resolve_string = options[:resolve_string] and resolve_string != ""
      request_options["$where"] = "function() { return this.extract.match(/#{resolve_string}/i); } "
    end
    all_glossaries = Glossary.all(request_options)
    if resolve_string and resolve_string != "" and options[:automatic_adding] and all_glossaries.size == 0
      puts "creating new entry =#{resolve_string}"
      new_glossary = Glossary.learn_one(resolve_string, ProductsFilterAnonymous.code_constructor(resolve_string))
      [{:label => new_glossary.label, :glossaries => [new_glossary], :constructor => new_glossary.constructor}]
    else
      puts "#{all_glossaries.size} inputs for entry =#{resolve_string}"
      all_glossaries.group_by(&:label).collect do |label, glossaries|
        { :label => label, :glossaries => glossaries, :constructor => glossaries.first.constructor } 
      end.sort { |x1, x2| x2[:glossaries].size <=> x1[:glossaries].size }
    end
  end

  def self.resolve_as_products_filter(resolve_string)
      array_glossaries = resolve(:resolve_string => resolve_string, :automatic_adding => true)
      raise "Error calling resolve #{resolve_string} returns []" if array_glossaries.size == 0
      eval(array_glossaries.first[:constructor])
  end

  # learning system
  # return a list of new glossaru objects
  def self.learn_multiple(extracts, constructor)
    pf = eval(constructor)
    extracts.collect { |extract| Glossary.learn_one(extract, pf) }
  end

  def self.learn_one(extract, constructor)
    pf = constructor.is_a?(ProductsFilter) ? constructor : eval(constructor)
    Glossary.create(:extract => extract, :constructor => constructor,
                    :label => pf.display_as,
                    :state =>  pf.is_a?(ProductsFilterAnonymous) ? "unmatched" : "matched")
  end

  def self.learn(extract, constructor) extract.is_a?(Array) ? learn_multiple(extract, constructor) : learn_one(extract, constructor) end

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

