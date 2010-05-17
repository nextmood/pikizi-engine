require 'products_filter'

class InterpretorController < ApplicationController

  # /edit_review/:id/:paragraph_id/:opinion_id
  # /edit_review/:id/:paragraph_id
  # /edit_review/:id   (edit the first paragraph review)

  def edit_review
    @review = Review.find(params[:id])

    @paragraphs = @review.paragraphs.reload
    @paragraph_id = params[:paragraph_id] ? BSON::ObjectID.from_string(params[:paragraph_id]) : @paragraphs.first.id
    @paragraph_previous_id = nil
    @paragraph_next_id = nil

    # compute the previous and next paragraph id
    this_is_the_next_paragraph = false
    paragraph_edited = nil
    previous_paragraph_is_not_set = true
    @paragraphs.each do |paragraph|
      if this_is_the_next_paragraph
        @paragraph_next_id = paragraph.id
        this_is_the_next_paragraph = false
      elsif paragraph.id == @paragraph_id
        this_is_the_next_paragraph = true
        previous_paragraph_is_not_set = false
        paragraph_edited = paragraph
      elsif previous_paragraph_is_not_set
        @paragraph_previous_id = @paragraph_id
      end
    end
              
    @existing_opinions = paragraph_edited.opinions.reload

    if params[:opinion_id]
      opinion_id = BSON::ObjectID.from_string(params[:opinion_id])
      @opinion = @existing_opinions.detect { |o| o.id == opinion_id }
    end


  end

  # get /cut_paragraph/:paragraph_id/:caret_position
  def cut_paragraph
    paragraph = Paragraph.find(params[:id])
    paragraph.review.cut_paragraph_at(paragraph, Integer(params[:caret_position]))
    redirect_to "/edit_review/#{review.id}/#{paragraph.id}"
  end

  def add_opinion_to_paragraph
    in_paragraph = Paragraph.find(params[:id])
    in_review = in_paragraph.review

    opinion = Opinion.const_get(params[:opinion_class]).create(:review_id => in_review.id, :written_at => in_review.written_at, :paragraph_id => in_paragraph.id, :user_id => @current_user.id, :category => in_review.category)
    # add default products filter

    if opinion.is_a?(Tip)
      opinion.update_attributes(:intensity_symbol => "very_high")
      in_review.products.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => p.id ).update_labels(p)
      end
    end

    if opinion.is_a?(Comparator)
      opinion.update_attributes(:operator_type => "same")
      first_product, last_product = in_review.products
      last_product ||= []
      last_product = [last_product] unless last_product.is_a?(Array)
      opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => first_product.id ).update_labels(first_product)
      last_product.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "compare_to", :product_id => p.id ).update_labels(p)
      end
    end

    if opinion.is_a?(Ranking)
      in_review.products.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => p.id ).update_labels(p)
      end
      opinion.products_filters << ProductsByShortcut.create(:opinion_id => opinion.id, :shortcut_selector => "all_products", :products_selector_dom_name => "scope_ranking" )
    end

    if opinion.is_a?(Rating)
      in_review.products.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => p.id ).update_labels(p)
      end
    end

    if opinion.is_a?(Neutral)
      in_review.products.each do |p|
        opinion.products_filters << ProductByLabel.create(:opinion_id => opinion.id, :products_selector_dom_name => "referent", :product_id => p.id ).update_labels(p)
      end
    end

    opinion.save
    opinion.update_status(@current_knowledge.get_products)
    session[:opinion_id_in_creation] = opinion.id

    redirect_to "/edit_review/#{in_review.id}/#{in_paragraph.id}/#{opinion.id}"
  end

  def remove_opinion_from_paragraph
    opinion = Opinion.find(params[:id])
    url = "/edit_review/#{opinion.review_id}/#{opinion.paragraph_id}"
    opinion.destroy
    redirect_to url
  end

  # this is the main form submit RJS
  def update_opinion
    @opinion = Opinion.find(params[:id])
    notification = nil
    @opinion.process_attributes(@current_knowledge, params)
    @opinion.save
    @opinion.update_status(@current_knowledge.get_products)
    @opinion.paragraph.update_status
    @opinion.review.update_status
    notification = "<span style='color:#{@opinion.error? ? 'red' : 'green'};'><b>Saved ...</b> #{@opinion.to_html}</span>"
    render :update do |page|
      page.replace("paragraph_edited", :partial => "paragraph_editor_opinion", :locals => { :opinion => @opinion, :notification => notification  })
    end
  end



  # adding a new product filters
  def add_products_filter
    name = params[:id]
    # create a new Product Filter
    products_filter = case params[:key_selector]
      when "by_label" then ProductByLabel.new(:products_selector_dom_name => "name")
      when "by_shortcut" then ProductsByShortcut.new(:products_selector_dom_name => "name")
      when "by_specification"
        pf = ProductsBySpec.new(:products_selector_dom_name => "name")
        pf.specification = @current_knowledge.get_specification_by_idurl("brand")
        pf
      else
        raise "error unknown key_sleector=#{params[:key_selector].inspect}"
    end
    render :update do |page|
      page.insert_html(:bottom, "#{name}_extra",
                       :partial => "products_selector_filter",
                       :locals => { :is_first_product_filter => false,
                                    :products_filter => products_filter,
                                    :name => name } )
    end
    
  end

  #this is a rjs form
  def add_usage
    render :update do |page|
      page.insert_html(:bottom, "list_usages_form", :partial => "usage_related", :locals => { :usage => Usage.new() } )
    end
  end

  #this is a rjs form  (just remove an element from the dom_id)
  def remove_from_form
    dom_id = params[:id]
    render :update do |page|
      page.replace(dom_id, "" )
    end
  end

  # changing specification in product selector
  # update the list of tags
  # this is a rjs
  def specification_selected
    dom_id = params[:id]
    name = params[:name]
    is_first_product_filter = params[:is_first_product_filter]
    products_filter = ProductsBySpec.new
    specification_selected_id = params[:specification_selected_id]
    specification_selected = Specification.find(specification_selected_id)
    products_filter.specification = specification_selected
    render :update do |page|
      page.replace(dom_id, :partial => "products_selector_filter",
          :locals => { :is_first_product_filter => is_first_product_filter, :products_filter => products_filter, :name => name })
    end
  end

  def opinion_ranking_changed

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

  # acceptance of an opinion
  # moving from to_review to ... to_review_ok or to_review_ko
  def censor_action
    opinion = Opinion.find(params[:id])
    raise "error wrong state=#{opinion.state}" unless opinion.to_review?
    censor_comment = params["censor_comment_#{opinion.id}"]
    case censor_code = params["censor_code_#{opinion.id}"]
      when "ok" then opinion.accept!
      when "ko" then opinion.reject!
      else
        raise "unknown censor code #{censor_code}"
    end
    opinion.update_attributes(:censor_code => censor_code, :censor_comment => censor_comment, :censor_date => Date.today, :censor_author_id => @current_user.id)
    redirect_to "/edit_review/#{opinion.review_id}/#{opinion.paragraph_id}/#{opinion.id}"    
  end

  # AUTOCOMPLETION...

  # new_usage
  def auto_complete_for_usage_label
    input = params[:usage][:label]
    render(:inline => "<ul>" << Usage.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  #products label
  def auto_complete_for_product_by_label_label
    input = params[:product_by_label][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end


end
