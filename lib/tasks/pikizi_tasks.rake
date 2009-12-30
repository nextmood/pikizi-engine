namespace :pikizi do

  desc "reset the Database"
  task :reset_db => :environment do
    Root.reset_db
  end

  desc "Load a domain"
  task :load_domain => :environment do
    unless ENV.include?("name")
      raise "usage: rake pikizi::load_domain name= a directory name in public/domains"
    end
    Knowledge.initialize_from_xml(ENV['name'])
  end


  desc "Check consistency of a domain"
  task :domain_quality_check => :environment do
    unless ENV.include?("name")
      raise "usage: rake pikizi::domain_quality_check name= a directory name in public/domains"
    end
    doc = XML::Document.file("#{ENV['name']}/knowledge/knowledge.xml")
    schema = XML::Schema.new("/schemas/knowledge.xsd")
    doc.validate_schema(schema) do |message, flag|
      puts "#{flag} #{message}"
    end
  end


  desc "Recompute all aggregations based on reviews on all products for a model"
  task :recompute_ratings => :environment do
    knowledge_idurl = ENV.include?("name") ? ENV['name'] : "cell_phones"
    knowledge = Knowledge.load(knowledge_idurl)


  end



  desc "Recompute all questions and choices counters for all knowledges"
  task :recompute_counters => :environment do

    # compute
    # hash_k_q_counter_presentation[knowledge_idurl][question_idurl] -> nb_presentation
    # hash_k_q_c_counter_ok[knowledge_idurl][question_idurl][choice_idurl] -> nb_ok

    # initialize...
    hash_k_q_counter_presentation = {}
    hash_k_q_c_counter_ok = {}

    Knowledge.xml_idurls.each do |knowledge_idurl|
      hash_q_c_counter_ok = hash_k_q_c_counter_ok[knowledge_idurl] = {}
      hash_q_counter_presentation = hash_k_q_counter_presentation[knowledge_idurl] = {}
      Knowledge.get_from_idurl(knowledge_idurl).questions.each do |question|
        hash_q_counter_presentation[question.idurl] = {:presentation => 0, :oo => 0}
        hash_q_c_counter_ok[question.idurl] = {}
        question.choices.each do |choice|
          hash_q_c_counter_ok[question.idurl][choice.idurl] = 0
        end
      end
    end

    # process each user
    User.xml_idurls.each do |user_idurl|
      user = User.create_from_xml(user_idurl)
      user.quizze_instances.each do |quizze_instance|
        quizze_instance.hash_answered_question_answers.each do |question_idurl, answers|
          answer = answers.last
          knowledge_idurl = answer.knowledge_idurl
          puts "knowledge_idurl=#{knowledge_idurl}, question_idurl=#{question_idurl}"
          hash_k_q_counter_presentation[knowledge_idurl][question_idurl][:presentation] += 1
          hash_k_q_counter_presentation[knowledge_idurl][question_idurl][:oo] += 1 unless answer.has_opinion?
          answer.choice_idurls_ok.each do |choice_idurl_ok|
            hash_k_q_c_counter_ok[knowledge_idurl][question_idurl][choice_idurl_ok] += 1
          end
        end
      end
    end


    # write the results in knowledge files
    hash_k_q_counter_presentation.each do |knowledge_idurl, hash_q_counter_presentation|
      knowledge = Knowledge.create_from_xml(knowledge_idurl)
      hash_q_counter_presentation.each do |question_idurl, counters|
        question = knowledge.get_question_by_idurl(question_idurl)
        question.nb_presentation_static = counters[:presentation]
        question.nb_oo_static = counters[:oo]
        # write in cache...
        Knowledge.counter_question_presentation(knowledge_idurl, question_idurl, :initialize => counters[:presentation])
        Knowledge.counter_question_oo(knowledge_idurl, question_idurl, :initialize => counters[:oo])

        hash_k_q_c_counter_ok[knowledge_idurl][question_idurl].each do |choice_idurl, counter_ok|
          choice = question.get_choice_from_idurl(choice_idurl)
          choice.nb_ok_static = counter_ok
          # write in cache...
          Knowledge.counter_choice_ok(knowledge_idurl, question_idurl, choice_idurl, :initialize => counter_ok)
        end
      end
      knowledge.save
    end

  end



end
