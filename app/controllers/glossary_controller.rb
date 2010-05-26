class GlossaryController < ApplicationController
  
  def index    
    if (glossaries_selected_ids = (params[:glossaries_selected] || [])).size > 0
      case params[:mode_field]
        when "merge"
        when "delete"
      end
    end
    @max_nb_glossaries = (params[:max_nb_glossaries] || 500)
    @resolve_string = params[:resolve_string]
    @glossaries = Glossary.resolve(:resolve_string => @resolve_string, :limit => @max_nb_glossaries, :automatic_adding => true)
    @nb_glossaries = @glossaries.size
  end

  def delete
      
  end

  def merge

  end

  #this is a rjs
  def match_unsolved
    glossary = Glossary.find(params[:id])
    render :update do |page|
      page.replace_html("unmatched_#{glossary.id}", :partial => "/glossary/editor", :locals => { :glossary => glossary })
    end
  end
  
  def close_editor
    glossary = Glossary.find(params[:id])
    render :update do |page|
      page.replace_html("unmatched_#{glossary.id}", :partial => "/glossary/glossary", :locals => { :glossary => glossary })
    end
  end
end
