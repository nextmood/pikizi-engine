require 'products_filter'

class InterpretorController < ApplicationController



  def test
    @review = Review.find(params[:id])
    @paragraph_index = Integer(params[:paragraph_index] || 0)
    opinion_id = params[:opinion_id] # for editing opinion


    @paragraphs = @review.paragraphs
    @paragraph = @paragraphs[@paragraph_index]


    @paragraphs_size = @paragraphs.size
    @is_last_paragraph = (@paragraph_index == @paragraphs_size - 1)
    @is_first_paragraph = (@paragraph_index == 0)

    @knowledge = @review.knowledge
    #session[:opinion_id_in_creation] = nil
    get_current_opinion(@review) # new opinion
    puts "curren_opinion=#{@current_opinion.inspect}"
  end




  # return the opinion we are working on / editing 
  def get_current_opinion(review=nil)
    unless @current_opinion
      unless opinion_id = session[:opinion_id_in_creation] and @current_opinion = Opinion.find(opinion_id)
        puts "creation....#{review.products.count}"
        @current_opinion = Opinion.create
        review.products.each do |p|
          @current_opinion.products_filters << ProductByLabel.create(:opinion_id => @current_opinion.id, :products_selector_dom_name => "referent", :display_as => p.label, :product_id => p.id )        
        end
        @current_opinion.products_filters << ProductsByShortcut.create(:opinion_id => @current_opinion.id, :shortcut_selector => "all_products", :products_selector_dom_name => "scope_ranking", :display_as => "all products" )

        session[:opinion_id_in_creation] = @current_opinion.id
      end
    end
    @current_opinion
  end

  # this a rjs
  def add_product_by_label
    get_current_opinion
    prefix = "product_"
    name, params_extra = params.detect { |k, v| k.has_prefix(prefix)}
    name = name.remove_prefix(prefix)
    if product = Product.first(:label => label = params_extra[:label])
      # existing product

      flash[:notice] = "existing product"
      @current_opinion.products_filters << ProductByLabel.create(:product_id => product.id, :opinion_id => @current_opinion.id, :products_selector_dom_name => name, :display_as => product.label )
    else
      # new product
      flash[:notice] = "new product"
    end

    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @current_opinion, :name => name })
    end

  end

  # this a remote form
  # work closely with partial interpretor/products_selector_by_shortcut
  def add_product_by_shortcut
    get_current_opinion
    name = params[:name]
    shortcut_key = params["#{name}_shortcut"]
    shortcuts = { "all_products" => "all products", "all_smartphones" => "all smartphones", "all_android" => "all android" }
    @current_opinion.products_filters << ProductsByShortcut.create(:opinion_id => @current_opinion.id, :shortcut_selector => shortcut_key, :products_selector_dom_name => name, :display_as => shortcuts[shortcut_key] )
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @current_opinion, :name => name })
    end    
  end

  # this is a remote post /interpretor/add_product_by_specification
  def add_product_by_specification
    mode_selection_tag = {"add all products matching ONE tag" => "or", "add all products matching ALL tags" => "and"}[params[:commit]]
    specification_selected = Specification.find(params[:specification_selected])
    specification_filter_datas = params[:specification_filter_datas]
    name = params[:name]
    get_current_opinion
    @current_opinion.products_filters << ProductsBySpec.create(:specification_id => specification_selected.id,
      :opinion_id => @current_opinion.id,
      :products_selector_dom_name => name,
      :display_as => "#{specification_selected.label} is " << specification_filter_datas.collect { |tag_idurl| specification_selected.lookup_tag_by_idurl(tag_idurl).label }.join("&nbsp;#{mode_selection_tag}&nbsp;"),
      :expressions => [specification_filter_datas],
      :mode_selection_tag  => mode_selection_tag)
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @current_opinion, :name => name })
    end
  end

  def delete_products_filter
    get_current_opinion
    name = params[:name]
    products_filter = ProductsFilter.find(params[:id])
    raise "no products_filter"   unless products_filter
    @current_opinion.products_filters.delete(products_filter)
    products_filter.destroy
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @current_opinion, :name => name })
    end
  end

  def toggle_preceding_operator
    get_current_opinion
    name = params[:name]
    products_filter_id = params[:id]
    products_filter = @current_opinion.products_filters.detect { |pf| pf.id.to_s == products_filter_id }
    raise "no products_filter"   unless products_filter
    products_filter.preceding_operator = (products_filter.preceding_operator == "and" ? "or" : "and")
    products_filter.save
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @current_opinion, :name => name })
    end
  end

  # work closely with helper   InterpretorHelper/radio_buttons
  def choice_selected
    get_current_opinion    
    choice_key = params[:id]
    name = params[:name]
    render :update do |page|
      page.replace_html("div_opinion_selector", :partial => choice_key, :locals => {:name => name, :opinion => @current_opinion })
    end

  end

  def cancel_product_selector
    get_current_opinion
    name = params[:id]
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @current_opinion, :name => name })
    end
  end

  def toggle_product_selector
    get_current_opinion
    name = params[:id]
    render :update do |page|
      page.replace_html("#{name}_extra", :partial => "products_selector_#{params[:key_selector]}", :locals => { :name => name, :opinion => @current_opinion })
    end
  end

  # changing specification in product selector
  # update the list of tags
  def specification_selected
    get_current_opinion
    name = params[:id]
    specification_selected_id = params[:specification_selected_id]
    specification_selected = Specification.find(specification_selected_id)
    render :update do |page|
      page.replace_html("specification_editor_#{name}", :partial => "products_selector_by_specification_tags", :locals => { :specification => specification_selected, :opinion => @current_opinion })
    end
  end

  def opinion_ranking_changed
    get_current_opinion
    order_number = Integer(params[:id])
    render :update do |page|
      page.replace_html("opinion_ranking_first", "")
      page.replace_html("opinion_ranking_second", "")
      if order_number >= 2
        page.replace_html("opinion_ranking_first", :partial => "products_selector", :locals => { :name => "ranking_first", :opinion => @current_opinion })
        page.insert_html(:top, "opinion_ranking_first", "<div style=\"font-weight:bold;\">Please specify the product ranked first</div>")
        if order_number >= 3
          page.replace_html("opinion_ranking_second", :partial => "products_selector", :locals => { :name => "ranking_second", :opinion => @current_opinion })
          page.insert_html(:top, "opinion_ranking_second", "<div style=\"font-weight:bold;\">Please specify the product ranked second</div>")
        end
      end
    end
  end
  
  # AUTOCOMPLETION...

  # Product(s) referents

  def auto_complete_for_product_referent_label
    input = params[:product_referent][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  # Product(s) comparaison

  def auto_complete_for_product_compare_with_label
    input = params[:product_compare_with][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  # Product(s) ranking 2nd and third

  def auto_complete_for_product_scope_ranking_label
    input = params[:product_scope_ranking][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end
  def auto_complete_for_product_ranking_first_label
    input = params[:product_ranking_first][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  def auto_complete_for_product_ranking_second_label
    input = params[:product_ranking_second][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end


end
