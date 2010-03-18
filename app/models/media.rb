require 'mongo_mapper'

# describe a media (image, movie, etc...)
class Media < Root

  include MongoMapper::Document
  


  key :label, String # summary of the opinion
  mount_uploader :media, MediaUploader

  timestamps!


end





