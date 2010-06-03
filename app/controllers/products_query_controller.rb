require 'products_query'

class ProductsQueryController < ApplicationController
  #layout nil

  def index
    # @pa1 = ProductsQueryAtom.process_attributes(Knowledge.first, { :products_query_atom_type => "ProductsQueryFromSpecification", :specification_id => "4bb367de43a76d0b67000001", :subset_tag_idurls => ["apple", "blackberry"]}).process_products_matching_query

    @products_query_1 = ProductsQuery.create_debug("pq_1", @current_knowledge.id,
      "products_query_atom_0" => { :products_query_atom_type => "ProductsQueryFromProductLabel", :product_label => "Blackberry Bold (T-Mobile)", :extension => "similar"}
    )

    @products_query_11 = ProductsQuery.create_debug("pq_11", @current_knowledge.id,
      "products_query_atom_0" => { :products_query_atom_type => "ProductsQueryFromProductLabel", :product_label => "Blackberry Bold (T-Mobile)"}
    )

    @products_query_2 = ProductsQuery.create_debug("pq_2", @current_knowledge.id,
      "products_query_atom_0" => { :products_query_atom_type => "ProductsQueryFromProductLabel", :product_label => "dummy", :extension => "similar"}
    )

    @products_query_22 = ProductsQuery.create_debug("pq_22", @current_knowledge.id,
      "products_query_atom_0" => { :products_query_atom_type => "ProductsQueryFromProductLabel", :product_label => "dummy"}
    )

    @products_query_3 = ProductsQuery.create_debug("pq_3", @current_knowledge.id,
      "products_query_atom_0" => { :products_query_atom_type => "ProductsQueryFromSpecification", :specification_id => "4bb367de43a76d0b67000001", :subset_tag_idurls => ["apple", "blackberry"]}
    )

    @products_query_4 = ProductsQuery.create_debug("pq_4", @current_knowledge.id,
      "products_query_atom_0" => { :products_query_atom_type => "ProductsQueryFromSpecification", :specification_id => "4bb367de43a76d0b67000003", :subset_tag_idurls => ["sprint", "att"], :mode_selection_tag => "any"}
    )

    @products_query_5 = ProductsQuery.create_debug("pq_5", @current_knowledge.id,
      "products_query_atom_0" => { :products_query_atom_type => "ProductsQueryFromSpecification", :specification_id => "4bb367de43a76d0b67000003", :subset_tag_idurls => ["sprint", "att"], :mode_selection_tag => "all"},
      "products_query_logical_0" => "or",
      "products_query_atom_1" => { :products_query_atom_type => "ProductsQueryFromProductLabel", :product_label => "Blackberry Bold (T-Mobile)", :extension => "similar"}
    )

  end

  # this a rjs for editing products_query_atom_specification
  def specification_selected
    raise "error"
    specification_selected = Specification.first(:knowledge_id => @current_knowledge.id, :idurl => params[:specification_selected_idurl])
    render :update do |page|
      page.replace_html(params[:dom_id_tags], tags_for_query_specifications(specification_selected))
    end
  end

end
