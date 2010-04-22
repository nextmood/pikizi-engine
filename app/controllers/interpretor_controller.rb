require 'products_filter'

class InterpretorController < ApplicationController

  # /edit_review/:id/:paragraph_id/add_opinion/class_opinion  
  # /edit_review/:id/:paragraph_id/:opinion_id
  # /edit_review/:id/:paragraph_id
  # /edit_review/:id

  def edit_review
    @review = Review.find(params[:id])
    @products4review = @review.products
    @paragraphs = @review.paragraphs.reload
    @paragraphs_size = @paragraphs.size

    @paragraph_index = 0
    @paragraphs.any? { |p| (p.id.to_s == params[:paragraph_id]) ? @paragraph = p : (@paragraph_index += 1; nil) }
    @paragraph ||= (@paragraph_index = 0; @paragraphs.first)
    @existing_opinions = @paragraph.opinions.reload

    if params[:opinion_id]
      @opinion = @existing_opinions.detect { |o| o.id.to_s == params[:opinion_id]}
    end
    @opinion ||= @existing_opinions.first
  end

  # get /cut_paragraph/:paragraph_id/:caret_position
  def cut_paragraph
    paragraph = Paragraph.find(params[:id])
    paragraph.review.cut_paragraph_at(paragraph, Integer(params[:caret_position]))
    redirect_to "/edit_review/#{review.id}/#{paragraph.id}"
  end

  def add_opinion_to_review
    in_paragraph = Paragraph.find(params[:id])
    in_review = in_paragraph.review
    products4review = in_review.products
    opinion = Opinion.const_get(params[:opinion_class]).create(:review_id => in_review.id, :paragraph_id => in_paragraph.id, :user_id => @current_user.id)
    # add default products filter

    if opinion.is_a?(Tip)
      opinion.update_attributes(:intensity_symbol => "very_high")
      puts "creating tip #{in_review.products.collect(&:label).join(', ')}"
      in_review.products.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => p.id )
      end
    end

    if opinion.is_a?(Comparator)
      opinion.update_attributes(:operator_type => "same")
      first_product, last_product = in_review.products
      last_product ||= []
      last_product = [last_product] unless last_product.is_a?(Array)
      opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => first_product.id )
      last_product.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "compare_to", :product_id => p.id )
      end
    end

    if opinion.is_a?(Ranking)
      in_review.products.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => p.id )
      end
      opinion.products_filters << ProductsByShortcut.create(:opinion_id => opinion.id, :shortcut_selector => "all_products", :products_selector_dom_name => "scope_ranking" )
    end

    if opinion.is_a?(Rating)
      in_review.products.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => p.id )
      end
    end
    opinion.save
    opinion.products_filters.each(&:update_labels)
    
    session[:opinion_id_in_creation] = opinion.id

    redirect_to "/edit_review/#{in_review.id}/#{in_paragraph.id}/#{opinion.id}"
  end

  def remove_opinion_from_review
    opinion = Opinion.find(params[:id])
    url = "/edit_review/#{opinion.review_id}/#{opinion.paragraph_id}"
    opinion.destroy
    redirect_to url
  end

  # add/remove a dimension from an opinion
  def dimension_toggle
    set_current_opinion(params[:id])
    dimension = Dimension.find(params[:dimension_id])
    raise "error" unless dimension
    if @opinion.dimension_ids.include?(dimension.id)
      # remove dimension
      @opinion.dimension_ids.delete(dimension.id)
    else
     # add dimension
      @opinion.dimension_ids << dimension.id
    end
    @opinion.save
    render :update do |page|
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  def comparator_operator_type_toggle
    set_current_opinion(params[:id])
    @opinion.update_attributes(:operator_type => params[:operator_type])
    render :update do |page|
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  def value_oriented_toggle
    set_current_opinion(params[:id])
    @opinion.update_attributes(:value_oriented => !@opinion.value_oriented)
    render :update do |page|
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  def tip_intensity_toggle
    set_current_opinion(params[:id])
    @opinion.update_attributes(:intensity_symbol => params[:intensity_symbol])
    render :update do |page|
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  def rating_toggle
    set_current_opinion(params[:id])
    field_name = params[:field_name]
    @opinion.update_attributes(field_name => Float(params[:value]))
    render :update do |page|
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  # this is a rjs form
  def set_opinion_extract
    set_current_opinion(params[:id])
    @opinion = Opinion.find(params[:id])
    @opinion.update_attributes(:extract => params[:new_extract].strip)
    puts "new_extract=#{params[:new_extract]}"
    content_paragraph = @opinion.paragraph.content_without_html
    render :update do |page|
      page.replace("div_paragraph_editor_bis", :partial => "paragraph_editor_bis", :locals => {:opinion => @opinion })
    end
  end

  # return the opinion we are working on / editing 
  def get_current_opinion()  @opinion ||= Opinion.find(session[:opinion_id_in_creation]) end


  def set_current_opinion(opinion_id)
    @opinion = Opinion.find(opinion_id)
    raise "no opinion !" unless @opinion
    session[:opinion_id_in_creation] = opinion_id
    @opinion
  end

  # this a rjs
  def add_product_by_label
    get_current_opinion
    prefix = "product_"
    name, params_extra = params.detect { |k, v| k.has_prefix(prefix)}
    name = name.remove_prefix(prefix)
    and_similar = (params[:and_similar] == "on")
    if product = Product.first(:label => label = params_extra[:label])
      # existing product

      flash[:notice] = "existing product"
      pf = ProductByLabel.create(:product_id => product.id, :and_similar => and_similar, :opinion_id => @opinion.id, :products_selector_dom_name => name)
      pf.update_labels(product)
      puts "updating ... label "
      @opinion.products_filters << pf
    else
      # new product
      flash[:notice] = "new product"
    end

    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @opinion, :name => name })
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end

  end

  # this a remote form
  # work closely with partial interpretor/products_selector_by_shortcut
  def add_product_by_shortcut
    get_current_opinion
    name = params[:name]
    shortcut_key = params["#{name}_shortcut"]
    shortcuts = ProductsByShortcut.shortcuts 
    @opinion.products_filters << (pf = ProductsByShortcut.create(:opinion_id => @opinion.id, :shortcut_selector => shortcut_key, :products_selector_dom_name => name, :display_as => shortcuts[shortcut_key] ))
    pf.update_labels
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @opinion, :name => name })
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end    
  end

  # this is a remote post /interpretor/add_product_by_specification
  def add_product_by_specification
    mode_selection_tag = {"add all products matching ONE tag" => "or", "add all products matching ALL tags" => "and"}[params[:commit]]
    specification_selected = Specification.find(params[:specification_selected])
    specification_filter_datas = params[:specification_filter_datas]
    name = params[:name]
    get_current_opinion
    @opinion.products_filters << (pf = ProductsBySpec.create(:specification_id => specification_selected.id,
      :opinion_id => @opinion.id,
      :products_selector_dom_name => name,
      :display_as => "#{specification_selected.label} is " << specification_filter_datas.collect { |tag_idurl| specification_selected.lookup_tag_by_idurl(tag_idurl).label }.join("&nbsp;#{mode_selection_tag}&nbsp;"),
      :expressions => [specification_filter_datas],
      :mode_selection_tag  => mode_selection_tag))
    pf.update_labels(specification_selected)
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @opinion, :name => name })
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  def delete_products_filter
    get_current_opinion
    name = params[:name]
    products_filter = ProductsFilter.find(params[:id])
    raise "no products_filter"   unless products_filter
    @opinion.products_filters.delete(products_filter)
    products_filter.destroy
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @opinion, :name => name })
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  def toggle_preceding_operator
    get_current_opinion
    name = params[:name]
    products_filter_id = params[:id]
    products_filter = @opinion.products_filters.detect { |pf| pf.id.to_s == products_filter_id }
    raise "no products_filter"   unless products_filter
    products_filter.preceding_operator = (products_filter.preceding_operator == "and" ? "or" : "and")
    products_filter.save
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @opinion, :name => name })
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  # work closely with helper   InterpretorHelper/radio_buttons
  def choice_selected
    get_current_opinion    
    choice_key = params[:id]
    name = params[:name]
    render :update do |page|
      page.replace_html("div_opinion_selector", :partial => choice_key, :locals => {:name => name, :opinion => @opinion })
    end

  end

  def cancel_product_selector
    get_current_opinion
    name = params[:id]
    render :update do |page|
      page.replace("ps_#{name}", :partial => "products_selector", :locals => {:opinion => @opinion, :name => name })
    end
  end

  def toggle_product_selector
    get_current_opinion
    name = params[:id]
    render :update do |page|
      page.replace_html("#{name}_extra", :partial => "products_selector_#{params[:key_selector]}", :locals => { :name => name, :opinion => @opinion })
    end
  end

  #this is a rjs form
  def add_usage
    @opinion = Opinion.find(params[:id])
    new_usage_text = (params[:opinion][:new_usage]).strip
    usage = Usage.find_by_label(new_usage_text)
    usage ||= Usage.create(:label => new_usage_text)
    @opinion.usages << usage
    @opinion.save
    render :update do |page|
      page.replace_html("usages_form", :partial => "usages_related", :locals => { :opinion => @opinion })
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })
    end
  end

  def remove_usage_from_opinion
    @opinion = Opinion.find(params[:id])
    usage = Usage.find(params[:usage_id])
    @opinion.usage_ids.delete(usage.id)
    @opinion.save
    render :update do |page|
      page.replace_html("usages_form", :partial => "usages_related", :locals => { :opinion => @opinion })
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })     
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
      page.replace_html("specification_editor_#{name}", :partial => "products_selector_by_specification_tags", :locals => { :specification => specification_selected, :opinion => @opinion })
    end
  end

  def opinion_ranking_changed
    get_current_opinion
    @opinion.update_attributes(:order_number => Integer(params[:id]))
    render :update do |page|
      page.replace_html("opinion_ranking_first", "")
      page.replace_html("opinion_ranking_second", "")
      if @opinion.order_number >= 2
        page.replace_html("opinion_ranking_first", :partial => "products_selector", :locals => { :name => "ranking_first", :opinion => @opinion })
        page.insert_html(:top, "opinion_ranking_first", "<div style=\"font-weight:bold;\">Please specify the product ranked first</div>")
        if @opinion.order_number >= 3
          page.replace_html("opinion_ranking_second", :partial => "products_selector", :locals => { :name => "ranking_second", :opinion => @opinion })
          page.insert_html(:top, "opinion_ranking_second", "<div style=\"font-weight:bold;\">Please specify the product ranked second</div>")
        end
      end
      page.replace("existing_opinion_#{@opinion.id}", :partial => "opinion", :locals => {:opinion => @opinion, :existing_opinion => @opinion })      
    end
  end
  
  # AUTOCOMPLETION...

  # new_usage

  def auto_complete_for_opinion_new_usage
    input = params[:opinion][:new_usage]
    render(:inline => "<ul>" << Usage.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  # Product(s) referents

  def auto_complete_for_product_referent_label
    input = params[:product_referent][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  # Product(s) comparaison

  def auto_complete_for_product_compare_to_label
    input = params[:product_compare_to][:label]
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
