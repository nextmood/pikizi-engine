class GlossaryController < ApplicationController
  
  def index

    @state_names = params[:state_names]
    @state_names ||= Glossary.list_states.collect(&:first)
    @max_nb_glossaries = (params[:max_nb_glossaries] || 500)
    @resolve_string = params[:resolve_string]
    @array_hash_glossaries = Glossary.resolve(:resolve_string => @resolve_string, :limit => @max_nb_glossaries, :states => @state_names, :automatic_adding => true)
    @nb_glossaries = @array_hash_glossaries.inject(0) { |s, hash_glossary| s += hash_glossary[:glossaries].size }
  end

end
