module ProductsQueryHelper

  # is the ProductsQuery form
  def products_query_atom_form(f, knowledge)
    if f.object.is_a?(ProductsQueryFromProductLabel)
      product_label = "<label>name of product</label><field>#{f.text_field(:product_label)}</field>"
      extension = ["similar", "next", "previous", "none"].collect { |tag| "#{f.radio_button(:extension, tag)}#{tag}" }.join('&nbsp;')
      "#{product_label} and products: (#{f.object.extension.inspect})  #{extension}"
    elsif f.object.is_a?(ProductsQueryFromSpecification)
      dom_id_tags = "tags_for_#{f.object.id}"
      specification_selector =  f.collection_select(:specification_tag_idurl,
                      options_for_query_specifications([], knowledge.specification_roots, 0),
                      :last,
                      :first,
                      {:prompt => "choose a feature..."},
                      :onchange => remote_function(:url => { :controller => "products_query",
                                                             :action => "specification_selected",
                                                             :dom_id => dom_id_tags  },
                                                   :with => "'specification_selected_idurl=' + this.value"))


      #list_tags =  specification.tags.collect { |t| "#{f.check_box("expressions", t.idurl)} #{t.label}" }.join(', ')
      list_tags = tags_for_query_specifications(f.object.specification)
      
      selection_mode = [[:all, "all tags"], [:any, "any tags"]].collect do |k,v|
        f.radio_button("mode_selection_tag", k) << v
      end.join(", ")

      "#{specification_selector}<div id=\"#{dom_id_tags}\">#{list_tags}<span style=\"font-size:80%; margin-left:10px;\">[#{selection_mode}]</span></div>"


    elsif f.object.is_a?(ProductsQueryFromShortcut)
      "ProductsQueryFromShortcut"
    else
      "?????"
    end
  end

=begin

 <%= products_filter_fields.collection_select(:specification_id, options_for_specifications_bis([], @current_knowledge.specification_roots, 0), :last, :first, {:prompt => "choose a feature..."},
                                 :onchange => remote_function(:url => { :action => "specification_selected", :id => dom_id, :name => name, :is_first_product_filter => is_first_product_filter },
                                                              :with => "'specification_selected_id=' + this.value") ) %>
                <%= link_to_remote(image_tag("icons/status_icon_delete.png", :border => 0), :url => { :action => "remove_from_form", :id => dom_id } ) %>
                <!-- list of tags -->
                <div>
                    <%= products_filter.specification.tags.collect { |t| "#{products_filter_fields.check_box("expressions",
                                                                                                             {:name => "products_filter_#{name}_#{products_filter.id}[expressions][]"},
                                                                                                             t.idurl, nil)} #{t.label}" }.join(', ') %>
                    <span style="font-size:80%; margin-left:10px;">
                        [<%= products_filter_fields.radio_button("mode_selection_tag", :all) %>all tags
                        <%= products_filter_fields.radio_button("mode_selection_tag", :any) %>any tags ]
                    </span>
                </div>

=end

  def tags_for_query_specifications(specification=nil)
    if specification
      specification.tags.collect { |t| "#{check_box_tag("expressions", t.idurl)} #{t.label}" }.join(', ')
    end
  end

  def options_for_query_specifications(l, specifications, level)
    specifications.each do |specification|
      (l << ["..." * level <<  specification.label, specification.idurl])  if  specification.is_compatible_grammar(:only_tags)
      options_for_query_specifications(l, specification.children, level + 1)
    end
    l
  end



  def products_atom_title(products_atom)
    query = products_atom.products_matching_query
    query_results = products_atom.process_products_matching_query
    "<span title=\"#{query || 'no query...'}\">#{products_atom.to_html} => </span><span title=\"#{query_results.collect(&:idurl).sort.join(', ')}\">#{pluralize(query_results.size, "product")} <small>#{query || 'no query...'}</small></span>"
  end
  
end
