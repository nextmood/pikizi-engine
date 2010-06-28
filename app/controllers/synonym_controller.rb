class SynonymController < ApplicationController

  # post /synonym_add
  def add
    synonym = Synonym.find(params[:id])
    synonym.update_attributes(:matches => synonym.matches << params[:match])
  end

  # post /synonym_resolve  
  def resolve
    Synonym.resolve(@current_knowledge.id, params[:search_string], :only_one => true)
  end

  def index
    @synonyms = @current_knowledge.synonyms
  end

end
