module KnowledgesHelper

  def admin_menu(knowledge)
    first_quiz = knowledge.quizzes.first
    quizz_text = pluralize(knowledge.nb_quizzes, "quiz")
    quizz_text = link_to(quizz_text, "/quiz/#{first_quiz.key}") if first_quiz
    [ [ :model , link_to(pluralize(knowledge.nb_features, "feature"), "/show/#{knowledge.key}") ],
      [ :matrix , link_to("Matrix", "/matrix/#{knowledge.key}") ],
      [ :distance , link_to("Distance", "/distance/#{knowledge.key}") ],
      [ :questions , link_to(pluralize(knowledge.nb_questions, "question"), "/questions/#{knowledge.key}") ],
      [ :quizzes , quizz_text   ]  ]
  end


  def model_selector(knowledge, menu_selected=:model)

    s = "<div>Knowledge base&nbsp;"
    s << select_tag("knowledge_key", options_for_select(Pikizi::Knowledge.xml_keys, knowledge.key))

    s << "&nbsp;"
    s << admin_menu(knowledge).collect do |menu_key, menu_html|
      menu_selected == menu_key ? "<b>#{menu_html}</b>" : menu_html
    end.join('&nbsp;|&nbsp;')
    s << "</div>"
    "<div class=\"pkz_menu\">#{s}</div>"
  end

  def feature_selector(knowledge, feature_selected_key)
    features_list = knowledge.each_feature_collect(false) { |feature| feature }.flatten
    select("option", "feature_key", features_list.collect { |f| [f.label_hierarchical, f.key]}, { :selected => feature_selected_key },
      :onchange => "window.location = '/distance/#{@knowledge.key}/' + document.getElementById('option_feature_key').value ")
  end




end
