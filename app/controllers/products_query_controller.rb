require 'products_query'

class ProductsQueryController < ApplicationController
  #layout nil

  def index

    @products_query_1 = ProductsQuery.birth("pq_1", @current_knowledge.id,
      ProductsQueryFromProductLabel.new(:product_label => "Blackberry Bold (T-Mobile)", :extension => "similar")
    )

    @products_query_11 = ProductsQuery.birth("pq_11", @current_knowledge.id,
      ProductsQueryFromProductLabel.new(:product_label => "Blackberry Bold (T-Mobile)")
    )

    @products_query_2 = ProductsQuery.birth("pq_2", @current_knowledge.id,
      ProductsQueryFromProductLabel.new(:product_label => "dummy", :extension => "similar")
    )

    @products_query_22 = ProductsQuery.birth("pq_22", @current_knowledge.id,
      ProductsQueryFromProductLabel.new(:product_label => "dummy")
    )

    @products_query_3 = ProductsQuery.birth("pq_3", @current_knowledge.id,
      ProductsQueryFromSpecification.new(:specification_idurl => "brand", :subset_tag_idurls => ["apple", "blackberry"])
    )

    @products_query_4 = ProductsQuery.birth("pq_4", @current_knowledge.id,
      ProductsQueryFromSpecification.new(:specification_idurl => "carriers", :subset_tag_idurls => ["sprint", "att"], :mode_selection_tag => "any")
    )

    @products_query_5 = ProductsQuery.birth("pq_5", @current_knowledge.id,
      ProductsQueryFromSpecification.new(:specification_idurl => "carriers", :subset_tag_idurls => ["sprint", "att"], :mode_selection_tag => "all"),
      "or",
      ProductsQueryFromProductLabel.new(:product_label => "Blackberry Bold (T-Mobile)", :extension => "similar")
    )

  end


  def auto_complete_for_product_label
    input = params[:products_query_from_product_label][:product_label]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

  # this a rjs for editing products_query_atom_specification
  def specification_selected
    name = params[:name]
    rank_index = params[:rank_index]
    specification_selected = Specification.first(:knowledge_id => @current_knowledge.id, :idurl => params[:specification_selected_idurl])
    puts "specification_selected CONTROLLER >>>> name=#{name}  rank_index=#{rank_index}  specification_selected=#{specification_selected.idurl}"

    render :update do |page|
      page.replace_html(params[:dom_id_tags], tags_for_query_specifications(name, rank_index, specification_selected))
    end
  end

  # process a form with multiple ProductsQuery
  def process_form
    @hash_queries_params = params.select { |k,v| k[0..0] == "p" }
    @hash_queries = @hash_queries_params.inject({}) { |h, (name, atom_params)| h[name] = ProductsQuery.process_attributes(name, @current_knowledge, atom_params); h  }
  end

  # process the products_query for the current user
  def process_current_products_query
    pq = ProductsQuery.process_attributes(current_products_query_name, @current_knowledge, params[current_products_query_name])
    pq.id = @current_products_query.id # wonder if it's not too nasty?'
    pq.save
    redirect_to "/myself"
  end

  # process a query an return a list of products matching
  def execute_query
    @query = params[:query]
    @query_results = ProductsQuery.execute_query(@query)
  end

  # this is a rjs
  def add_line
    name = params[:name]
    params[:knowledge_id] = @current_knowledge.id
    products_query_atom = ProductsQueryAtom.process_attributes(params)
    products_query_atom.preceding_operator = "or"
    render :update do |page|
      page.insert_html(:bottom, "dom_atoms_#{name}", products_query_atom_form(name, products_query_atom, @current_knowledge))
    end
  end

    # this is a rjs
  def remove_line
    render :update do |page|
      page.replace("atom_form_#{params[:id]}", "")
    end
  end

end
