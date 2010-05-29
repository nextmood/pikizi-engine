class GlossaryController < ApplicationController
  
  def index    
    if (glossaries_selected_ids = (params[:glossaries_selected] || [])).size > 0
      case params[:mode_field]
        when "merge"
        when "delete"
      end
    end
    @max_nb_glossaries = Integer((params[:max_nb_glossaries] || 500))
    @glossaries = Glossary.all(:limit => @max_nb_glossaries)
    @nb_glossaries = @glossaries.size
  end

  def delete
      
  end

  def merge_in_proposal
    glossary_matched = Glossary.find(params[:id])
    glossary_unmatched = Glossary.find(params[:glossary_unmatched_id])
    glossary_matched.merge(glossary_unmatched)
    redirect_to "/glossary"
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
