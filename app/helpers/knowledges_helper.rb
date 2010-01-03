module KnowledgesHelper

  def admin_menu(knowledge)
    [ [ :matrix , link_to(pluralize(knowledge.nb_features, "feature"), "/show/#{knowledge.idurl}") ],
      #[ :distance , link_to("Distance", "/distance/#{knowledge.idurl}") ],
      [ :questions , link_to(pluralize(knowledge.nb_questions, "question"), "/questions/#{knowledge.idurl}") ],
      [ :quizzes , link_to(pluralize(knowledge.nb_quizzes, "quizze"), "/quizzes/#{knowledge.idurl}")   ] ,
      [ :users , link_to("users", "/users")   ] ]
  end


  def model_selector(knowledge, menu_selected=:model)

    s = "<div>Knowledge base&nbsp;"
    s << select_tag("knowledge_idurl", options_for_select(Knowledge.all_key_label(:only => :idurl), knowledge.idurl))

    s << "&nbsp;"
    s << admin_menu(knowledge).collect do |menu_key, menu_html|
      menu_selected == menu_key ? "<b>#{menu_html}</b>" : menu_html
    end.join('&nbsp;|&nbsp;')
    s << "</div>"
    "<div class=\"pkz_menu\">#{s}</div>"
  end

  def feature_selector(knowledge, feature_selected_idurl)
    select("option", "feature_idurl", knowledge.features_all.collect { |f| [f.label_full, f.idurl]}, { :selected => feature_selected_idurl },
      :onchange => "window.location = '/distance/#{@knowledge.idurl}/' + document.getElementById('option_feature_idurl').value ")
  end




end
