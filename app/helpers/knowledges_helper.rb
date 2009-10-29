module KnowledgesHelper

  def admin_menu(knowledge)
    first_quiz = knowledge.quizzes.first
    quizz_text = pluralize(knowledge.nb_quizzes, "quiz")
    quizz_text = link_to(quizz_text, "/quiz/#{first_quiz.idurl}") if first_quiz
    [ [ :matrix , link_to(pluralize(knowledge.nb_features, "feature"), "/matrix/#{knowledge.idurl}") ],
      [ :distance , link_to("Distance", "/distance/#{knowledge.idurl}") ],
      [ :questions , link_to(pluralize(knowledge.nb_questions, "question"), "/questions/#{knowledge.idurl}") ],
      [ :quizzes , quizz_text   ] ,
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
    features_list = knowledge.each_feature_collect(false) { |feature| feature }.flatten
    select("option", "feature_idurl", features_list.collect { |f| [f.label_full, f.idurl]}, { :selected => feature_selected_idurl },
      :onchange => "window.location = '/distance/#{@knowledge.idurl}/' + document.getElementById('option_feature_idurl').value ")
  end




end
