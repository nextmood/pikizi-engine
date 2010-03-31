module InterpretorHelper

  def radio_buttons(name, choices, choice_key_selected)
    choices.collect do |choice|
      choice_label, choice_key = choice.is_a?(Array) ? choice : [choice.humanize, choice]
      radio_button_tag(name, choice_key, choice_key == choice_key_selected,
         :onclick => remote_function(
           :url => { :action => "choice_selected", :id => choice_key, :name => name })) << choice_label
    end.join()
  end

  def options_for_dimensions(knowledge, options={})
    options_for_select(options_for_dimensions_bis([], knowledge.dimension_root, 0))
  end

  def options_for_dimensions_bis(l, dimension, level)
    l << ["..." * level <<  dimension.label, dimension.id]
    dimension.children.each  { |d|  options_for_dimensions_bis(l, d, level + 1) }
    l
  end

  def options_for_specifications(knowledge, options={})
    options_for_select(options_for_specifications_bis([], knowledge.specifications, 0))
  end

  def options_for_specifications_bis(l, specifications, level)
    specifications.each do |specification|
      l << ["..." * level <<  specification.label, specification.id]
      options_for_specifications_bis(l, specification.children, level + 1)
    end
    l
  end

    #mode is either :comparator or :related
  def dimension_feature(a_knowledge, mode)
    l = (mode == :comparator ? [["",""]] : [])
    a_knowledge.each_feature do |feature|
      l << [feature.label_select_tag, feature.idurl] if feature.is_compatible_grammar(mode)
    end
    l
  end

end

