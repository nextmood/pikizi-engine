module SourcesHelper


  def pkz_date(d)
    d.strftime(Root.default_date_format) if d
  end

  def link_2_product(source_product, options={})

    s = if options[:sid]
      link_to(source_product.label, {:controller => "sources", :action => "show_product", :id => source_product.source_id, :sid => options[:sid]}, :class => "pkz_link")
    else
      link_to(source_product.label, {:controller => "sources", :action => "show_product", :id => source_product.id }, :class => "pkz_link")
    end

    s << "<span class='pkz_small pkz_next'>#{source_product.sid}</span>"
  end

end
