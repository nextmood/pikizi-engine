

# Availability is a set of valid prices by merchant for this product
class Merchant
  include MongoMapper::Document

  key :label, String
  key :url, String
  
  many :offers, :polymorphic => true

end