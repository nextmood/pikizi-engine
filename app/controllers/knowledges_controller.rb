
require 'google.rb'

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
    @knowledge, @products, @products_selected = get_products_selected(params)
    @feature = params[:feature_idurl] ? @knowledge.get_feature_by_idurl(params[:feature_idurl]) : @knowledge.features.first
    # compute graph
    @feature.distance_graph(@products_selected)
    
  end


  def show
    @knowledge, @products, @products_selected = get_products_selected(params)
    @features = @knowledge.each_feature_collect { |feature| feature }.flatten
  end

  def list_opinions
    @knowledge, @products, @products_selected = get_products_selected(params)    
  end

  def get_products_selected(params)
    knowledge =  Knowledge.load_db(params[:knowledge_idurl])
    products = knowledge.products.sort! { |p1, p2| p1.idurl <=> p2.idurl }
    pidurls_selected = params[:select_product_idurls]
    pidurls_selected ||= session[:pidurls_selected]
    pidurls_selected ||= products.collect(&:idurl).first(3)
    session[:pidurls_selected] = pidurls_selected
    [knowledge, products, products.select { |p| pidurls_selected.include?(p.idurl) }]
  end


  # this is rjs
  def feature_value_edit
    knowledge =  Knowledge.load_db(params[:knowledge_idurl])
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    product =  Product.load_db(params[:product_idurl], knowledge)
    dom_id = "cell_#{feature.idurl}_#{product.idurl}"
    mode = params[:mode] # in "edit", "cancel"
    partial_name = "/knowledges/feature_value_#{ params[:mode] == 'cancel' ? 'show' : 'edit' }"
    render :update do |page|
      page.replace(dom_id, :partial => partial_name,
                  :locals => {:knowledge => knowledge, :feature => feature, :product => product})
    end
  end


  # thsi is rjs
  def feature_edit
    knowledge =  Knowledge.load_db(params[:knowledge_idurl])
    feature = knowledge.load_db(params[:feature_idurl])
    dom_id = "cell_#{feature.idurl}"
    mode = params[:mode] # in "edit", "cancel"
    partial_name = "/knowledges/feature_#{ params[:mode] == 'cancel' ? 'show' : 'edit' }"
    render :update do |page|
      page.replace(dom_id, :partial => partial_name, 
                  :locals => { :knowledge => knowledge, :feature => feature, :tr_id => feature.dom_id })
    end
  end




  # GET /aggregations/:knowledge_idurl/model/:product_idurl/[:feature_idurl]
  def aggregations
    @knowledge = Knowledge.load_db(params[:knowledge_idurl])
    @feature = @knowledge.get_feature_by_idurl(params[:feature_idurl] || params[:knowledge_idurl])
    @product = Product.load_db(params[:product_idurl])
    @aggregations = @knowledge.get_aggregations(@product)
  end


  def test_gbase
    @results = nil
    if @query = params[:query]
      @gurl, @results, @feed = gsearch(:q => @query, :bq => "[item type:products]" )
    end
  end

end
