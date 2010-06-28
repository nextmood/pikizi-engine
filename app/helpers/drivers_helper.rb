module DriversHelper


  def pkz_date(d)
    d.strftime(Root.default_date_format) if d
  end

  def link_2_product(driver_product)
    s = if driver_product.product_id
      link_to("<b>#{driver_product.label}</b>", {:controller => "drivers", :action => "show_product", :id => driver_product.id }, :class => "pkz_link")
    else
      link_to(driver_product.label, {:controller => "drivers", :action => "show_product", :id => driver_product.driver_id, :sid => driver_product.sid}, :class => "pkz_link")
    end
    #s << "<span class='pkz_small pkz_next'>#{driver_product.sid}</span>"
    s
  end

end
