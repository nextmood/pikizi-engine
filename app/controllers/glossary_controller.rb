class GlossaryController < ApplicationController
  
  def index

    @max_nb_glossaries = (params[:max_nb_glossaries] || 500)
    @resolve_string = params[:resolve_string]
    @glossaries = Glossary.resolve(:resolve_string => @resolve_string, :limit => @max_nb_glossaries, :automatic_adding => true)
    @nb_glossaries = @glossaries.size
  end

end
