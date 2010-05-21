
# this is a list of opinions (use in import)

class Ocollection

  include MongoMapper::Document

  key :label, String

  key :opinion_ids, Array # an array of opinions id
  many :opinions, :in => :opinion_ids
  
  # nb opinions in this collection
  def nb_opinions() opinion_ids.size end

  # adding an opinion to this collection
  def add(opinion, should_save=true)
    self.opinions << opinion
    update_attributes(:opinion_ids => opinion_ids) if should_save
  end

  # removing this opinion from the collection
  def remove(opinion_id, should_save=true)
    self.opinion_ids.delete(opinion_id)
    self.opinions.delete_if { |o| o.id == opinion_id }    
    update_attributes(:opinion_ids => opinion_ids) if should_save
  end
  
end