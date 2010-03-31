

class InterpretorController < ApplicationController

  
  def test
    @knowledge = Knowledge.first(:idurl => params[:id])
    if opinion_id = session[:opinion_id_in_creation]
      @opinion = Opinion.find(opinion_id)
    else
      @opinion = Opinion.create
      session[:opinion_id_in_creation] = @opinion.id
    end
  end


  def add_product_by_label
    prefix = "product_"
    name, params_extra = params.detect { |k, v| k.has_prefix(prefix)}
    name = name.remove_prefix(prefix)
    if product = Product.first(:label => label = params_extra[:label])
      # existing product
      flash[:notice] = "existing product"
    else
      # new product
      flash[:notice] = "new product"
    end

    render :update do |page|
      page.insert_html(:bottom, "#{name}_list", :partial => "product_label", :locals => {:product => product, :product_label => label})      
      page.replace_html("#{name}_extra", :partial => "products_selector_bis", :locals => { :name => name, :key_selector => :by_label })
    end

  end

  # work closely with helper   InterpretorHelper/radio_buttons
  def choice_selected
    choice_key = params[:id]
    name = params[:name]
    transalation = { "comparator_tip" => :comparator_tip, "comparator_rating" => :comparator_rating, "comparator_ranking" => :comparator_ranking, "comparator_comparaison" => :comparator_comparaison }
    key_selector = transalation[choice_key]

    render :update do |page|
      case key_selector
        when :comparator_tip, :comparator_rating, :comparator_ranking, :comparator_comparaison
          page.replace_html("div_comparator", :partial => choice_key)
        else
          page.replace_html("div_comparator", "error key_selector=#{key_selector.inspect} choice_key=#{choice_key.inspect}")
      end
    end

  end

  def toggle_product_selector
    name = params[:id]
    key_selector = params[:key_selector].intern
    render :update do |page|
      page.replace_html("#{name}_extra", :partial => "products_selector_bis", :locals => { :name => name , :key_selector => key_selector })
    end
  end

  def specification_selected
    name = params[:id]
    specification_selected = Specification.find(params[:specification_selected_id])

    render :update do |page|
      page.replace_html("specification_editor_#{name}", :partial => "products_selector_by_specification", :locals => { :specification => specification_selected })
    end
  end

  # AUTOCOMPLETION...

  # Product(s) referents

  def auto_complete_for_product_referent_label
    input = params[:product_referent][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  # Product(s) comparaison

  def auto_complete_for_product_compare_label
    input = params[:product_compare][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  # Product(s) ranking 2nd and third

  def auto_complete_for_product_2nd_label
    input = params[:product_2nd][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  def auto_complete_for_product_3rd_label
    input = params[:product_3rd][:label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end


end
