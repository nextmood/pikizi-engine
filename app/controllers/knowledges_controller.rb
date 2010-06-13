
require 'google.rb'
require 'paginator'

class KnowledgesController < ApplicationController

  # layout "minimal", :only => :quizze


  # GET /knowledges
  # GET /knowledges.xml
  # return the most recent knowledge
  def index
    knowledge = Knowledge.all( :order => "updated_at DESC").first
    raise "no knowledge, in database idurls=#{ Knowledge.all.collect(&:idurl).join(', ')} (#{ Knowledge.all.size})" unless knowledge and knowledge.idurl
    respond_to do |format|
      format.html { redirect_to("/show/#{knowledge.idurl}") }
      format.xml  { render(:xml => Knowledge) }
    end

  end

  def distance
    @products, @products_selected = get_products_selected
    @feature = params[:feature_idurl] ? @current_knowledge.get_specification_by_idurl(params[:feature_idurl]) : @current_knowledge.features.first
    # compute graph
    @feature.distance_graph(@products_selected)
    
  end

  # --------------------------------------------------------------
  # BEGIN Dimension editor
  # --------------------------------------------------------------

  def dimensions_list
    @dimension_root =  @current_knowledge.dimension_root
  end

  # this is a rjs
  def edit_dimension_open
    dimension_id = BSON::ObjectID.from_string(params[:id])
    dimension = @current_knowledge.get_dimension_by_id(dimension_id)
    raise "***** error #{dimension_id.inspect} == #{dimension.inspect}" unless dimension
    render :update do |page|
      page.replace_html("div_dimension_extra_#{dimension.id}", :partial => "/knowledges/dimension_edit", :locals => {  :dimension => dimension })
    end
  end

  # this is a rjs
  def edit_dimension_usages_open
    dimension_id = BSON::ObjectID.from_string(params[:id])
    dimension = @current_knowledge.get_dimension_by_id(dimension_id)
    raise "***** error #{dimension_id.inspect} == #{dimension.inspect}" unless dimension
    render :update do |page|
      page.replace_html("div_dimension_extra_#{dimension.id}", :partial => "/knowledges/dimension_usages", :locals => {  :dimension => dimension })
    end
  end

  # this is a rjs
  def edit_dimension_opinions_open
    dimension_id = BSON::ObjectID.from_string(params[:id])
    dimension = @current_knowledge.get_dimension_by_id(dimension_id)
    raise "***** error #{dimension_id.inspect} == #{dimension.inspect}" unless dimension
    render :update do |page|
      page.replace_html("div_dimension_extra_#{dimension.id}", :partial => "/knowledges/dimension_opinions", :locals => {  :dimension => dimension })
    end
  end

  def delete_dimension
    dimension_id = BSON::ObjectID.from_string(params[:id])
    dimension = @current_knowledge.get_dimension_by_id(dimension_id)
    dimension.destroy
    redirect_to "/dimensions_list"
  end

  # this is the form update
  # editing the dimension
  # this isa remote form
  def update_dimension
    dimension_id = BSON::ObjectID.from_string(params[:id])
    dimension = @current_knowledge.get_dimension_by_id(dimension_id)
    if parent_id = params[:dimension][:parent_id]
      params[:dimension][:parent_id] = BSON::ObjectID.from_string(parent_id)
    end
    dimension.update_attributes(params[:dimension])
    render :update do |page|
      page.replace_html("list_dimensions", :partial => "dimensions",
         :locals => {  :dimensions => [@current_knowledge.dimension_root] })
    end
  end

  # this a rjs  (for cancel)
  def remove_dimension_editor
    dimension_id = params[:id]
    render :update do |page|       
      page.replace_html("div_dimension_extra_#{dimension_id}", "")
    end
  end


  # --------------------------------------------------------------
  # BEGIN Usage editor
  # --------------------------------------------------------------

  def self.get_paginator_usages(page=1, search_label=nil)
    pager = Paginator.new(Usage.count, 150) do |offset, per_page|
      options = {:offset => offset, :limit => per_page, :order => 'nb_opinions desc'}
      # see http://wiki.github.com/jnunemaker/mongomapper/using-mongomapper-and-where for the where clause ... really powerful
      # options.merge("$where" => "function() { return this.label.match(/#{search_label}/i); }") if search_label
      options.merge!(:label => Regexp.new(search_label, true)) if search_label
      Usage.all(options)
    end
    pager.page(page)
  end

  def usages_list
    @search_label =  params[:search_label]
    case params[:submit_mode]

      when "submit_merge" 
        if (usage_selected_ids = (params[:usage_selected_ids] || [])).size >= 2
          usages_tail = Usage.find(usage_selected_ids)
          usage_first = usages_tail.shift
          usages_tail.each do |usage|
            usage_first.label = "#{usage_first.label} + #{usage.label}"
            usage.opinions.each do |opinion|
              unless opinion.usage_ids.include?(usage_first.id)
                opinion.usage_ids << usage_first.id
                opinion.save
              end
            end
            usage.destroy
          end
          usage_first.save
        end

      when "submit_delete"
        (params[:usage_selected_ids] || []).each { |usage_id| Usage.find(usage_id).destroy }

    end
    @usages = KnowledgesController.get_paginator_usages(params[:page], @search_label)
  end


  # this is a rjs
  def edit_usage_open
    usage_id = BSON::ObjectID.from_string(params[:id])
    usage = Usage.find(usage_id)
    raise "***** error #{usage_id.inspect} == #{usage.inspect}" unless usage
    render :update do |page|
      page.replace_html("div_usage_extra_#{usage.id}", :partial => "/knowledges/usage_edit", :locals => { :usage => usage })
    end
  end

  def delete_usage
    usage_id = BSON::ObjectID.from_string(params[:id])
    usage = Usage.find(usage_id).destroy
    redirect_to "/usages_list"
  end

  # this is the form update
  # editing the usage
  # this isa remote form
  def update_usage
    usage_id = BSON::ObjectID.from_string(params[:id])
    product = Product.find(params[:product_id])
    usage = Usage.find(usage_id)
    usage.update_attributes(params[:usage])
    render :update do |page|
      page.replace_html("list_usages", :partial => "usages", :locals => { :usages => KnowledgesController.get_paginator_usages(params[:current_page]) })
    end
  end

  # this a rjs  (for cancel)
  def remove_usage_editor
    usage_id = params[:id]
    render :update do |page|
      page.replace_html("div_usage_extra_#{usage_id}", "")
    end
  end

  # --------------------------------------------------------------
  # END Usage editor
  # --------------------------------------------------------------

  def show
    @products, @products_selected = get_products_selected
  end

  def list_opinions
    @products, @products_selected = get_products_selected
  end



  # GET /aggregations/:knowledge_idurl/model/:product_idurl/[:feature_idurl]
  def aggregations
    @feature = @current_knowledge.get_feature_by_idurl(params[:feature_idurl] || params[:knowledge_idurl])
    @product = Product.load_db(params[:product_idurl])
    @aggregations = @current_knowledge.get_aggregations(@product)
  end


  def test_gbase
    @results = nil
    if @query = params[:query]
      @gurl, @results, @feed = gsearch(:q => @query, :bq => "[item type:products]" )
    end
  end

end
