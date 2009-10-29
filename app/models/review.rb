require 'mongo_mapper'

# describe an opinion of a user for a given product/feature
# with associated backgrounds
# rating in between ).0 and 1.0
class Review < Root
  
  include MongoMapper::Document

  key :type, String
  key :knowledge_url, String
  key :feature_url, String
  key :product_url, String
  key :media_url, String
  key :data, String

  key :user_id, String
  belongs_to :user
  
  key :updated_at, Time

  timestamps!

  attr_accessor :knowledge_idurl, :feature_idurl, :product_idurl, :timestamp, :db_id, :min_rating, :max_rating, :value, :hash_idurl_background

  def self.is_main_document() true end

  def initialize_from_xml(xml_node)
    super(xml_node)
    self.knowledge_idurl = xml_node['knowledge_idurl']
    self.feature_idurl = xml_node['feature_idurl']
    self.product_idurl = xml_node['product_idurl']
    self.min_rating = xml_node['min_rating']
    self.max_rating = xml_node['max_rating']
    self.db_id = xml_node['db_id']
    self.timestamp =  Time.parse(xml_node['timestamp']) if xml_node['timestamp']
    self.value = Float(xml_node['value'])
    self.hash_idurl_background = Root.get_hash_from_xml(xml_node, 'background', 'idurl') { |node_background| Background.create_from_xml(node_background) }
  end

  def generate_xml(top_node)
    node_opinion = super(top_node)
    node_opinion['value'] = value.to_s
    hash_idurl_background.each { |idurl, background| background.generate_xml(node_opinion) }  if hash_idurl_background
    node_opinion['db_id'] = db_id.to_s if db_id
    node_opinion['knowledge_idurl'] = knowledge_idurl
    node_opinion['feature_idurl'] = feature_idurl
    node_opinion['min_rating'] = min_rating
    node_opinion['max_rating'] = max_rating
    node_opinion['product_idurl'] = product_idurl
    node_opinion['timestamp'] = timestamp.strftime(Root.default_date_format) if timestamp
    node_opinion
  end
  
end

