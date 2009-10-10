module KnowledgesHelper

  def admin_menu(knowledge)
    first_quiz = knowledge.quizzes.first
    quizz_text = pluralize(knowledge.nb_quizzes, "quiz")
    quizz_text = link_to(quizz_text, "/quiz/#{first_quiz.key}") if first_quiz
    [ [ :model , link_to(pluralize(knowledge.nb_features, "feature"), "/show/#{knowledge.key}") ],
      [ :products , pluralize(knowledge.nb_products, "product") ],
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

end
