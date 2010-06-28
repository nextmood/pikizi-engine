module ProductsQueryHelper
  

  def products_query_atom_form(name, products_query_atom, knowledge)
    prefix = link_to_remote(image_tag("icons/status_icon_delete.png", :border => 0) << "&nbsp;", :url => {:controller => "products_query", :action => "remove_line", :id => products_query_atom.id })
    #prefix << "#{products_query_atom.rank_index}) "

    atom_form = fields_for(name, nil) do |products_query_fields|

      products_query_fields.fields_for("atom#{products_query_atom.rank_index}", products_query_atom) do |products_query_atom_fields|
        prefix << products_query_atom_fields.hidden_field(:products_query_atom_type)
        prefix << products_query_atom_fields.hidden_field(:knowledge_id)
        prefix << products_query_atom_fields.hidden_field(:rank_index)
        prefix  << products_query_atom_fields.collection_select(:preceding_operator, [["and", "and"], ["or", "or"]], :last, :first) if products_query_atom.preceding_operator

        # FromProductLabel ....
        if products_query_atom.is_a?(ProductsQueryFromProductLabel)
          product_label_text_field = products_query_atom_fields.text_field_with_auto_complete(:product_label, {:size => 25}, {:url => { :controller => "products_query", :action => "auto_complete_for_product_label" }, :method => :get })
          product_label = "<label>name of product</label><field>#{product_label_text_field}</field>"
          extension = ["similar", "next", "previous", "none"].collect { |tag| "#{products_query_atom_fields.radio_button(:extension, tag)}#{tag}" }.join('&nbsp;')
          "#{product_label} and products: #{extension}"

        # FromSpecification...
        elsif products_query_atom.is_a?(ProductsQueryFromSpecification)
          dom_id_tags = "tags_for_#{products_query_atom.id}"
          specification_selector =  products_query_atom_fields.collection_select(:specification_idurl,
                          options_for_query_specifications([], knowledge.specification_roots, 0),
                          :last,
                          :first,
                          {:prompt => "choose a feature..."},
                          :onchange => remote_function(:url => { :controller => "products_query",
                                                                 :action => "specification_selected",
                                                                 :dom_id_tags => dom_id_tags,
                                                                 :name => name,
                                                                 :rank_index => products_query_atom.rank_index  },
                                                       :with => "'specification_selected_idurl=' + this.value"))


          list_tags = tags_for_query_specifications(name, products_query_atom.rank_index, products_query_atom.specification, products_query_atom.subset_tag_idurls)

          selection_mode = [[:all, "all tags"], [:any, "any tags"]].collect do |k,v|
            products_query_atom_fields.radio_button("mode_selection_tag", k) << v
          end.join(", ")

          "#{specification_selector}<span id=\"#{dom_id_tags}\">#{list_tags}<span style=\"font-size:80%; margin-left:10px;\">[#{selection_mode}]</span></span>"

        # FromShortcut..
        elsif products_query_atom.is_a?(ProductsQueryFromShortcut)
          "ProductsQueryFromShortcut"
        else
          raise "unknown products_query_atom class = #{products_query_atom.class}"
        end
      end
    end

    "<div style=\"margin-left:5px; margin-bottom:3px;\" id=\"atom_form_#{products_query_atom.id}\" >
        #{prefix}#{atom_form}
    </div>"
  end

  def tags_for_query_specifications(name, rank_index, specification, subset_tag_idurls=[])
    if specification
      specification.tags.collect { |t| "#{check_box_tag("#{name}[atom#{rank_index}]subset_tag_idurls[]", t.idurl, subset_tag_idurls.include?(t.idurl))} #{t.label}" }.join(', ')
    end
  end

  def options_for_query_specifications(l, specifications, level)
    specifications.each do |specification|
      (l << ["..." * level <<  specification.label, specification.idurl])  if  specification.is_compatible_grammar(:only_tags)
      options_for_query_specifications(l, specification.children, level + 1)
    end
    l
  end


  
end
