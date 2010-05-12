module InterpretorHelper



  def options_for_dimensions(knowledge, options={})
    l = options_for_dimensions_bis([], knowledge.dimension_root, 0, options[:max_level] || 10)
    l = options_for_select(l, options[:selected]) unless options[:raw]
    l
  end

  def options_for_dimensions_bis(l, dimension, level, max_level)
    l << ["..." * level <<  dimension.label, dimension.id]
    dimension.children.each  { |d|  options_for_dimensions_bis(l, d, level + 1, max_level) } if level < max_level
    l
  end

  def options_for_specifications(knowledge, selected_specification_id=nil)
    l = options_for_specifications_bis([], knowledge.specification_roots, 0)
    options_for_select(l, selected_specification_id)
  end

  def options_for_specifications_bis(l, specifications, level)
    specifications.each do |specification|
      (l << ["..." * level <<  specification.label, specification.id])  if  specification.is_compatible_grammar(:only_tags)
      options_for_specifications_bis(l, specification.children, level + 1)
    end
    l
  end



  def check_box_value_oriented(opinion_form, style=nil)
    style = "style=\"#{style}\"" if style
    "<div #{style}>" << opinion_form.check_box(:value_oriented) << "&nbsp;for $ value</div>"
  end

end

