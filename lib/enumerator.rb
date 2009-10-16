

def enumerator_inclusive(choice_list, debug=nil, n=nil, result=[], current_proba=1.0, cumulator={})
  n ||= choice_list.size
  if n == 0
    cumulator = each_propa_choices(current_proba, result, cumulator, debug)
  else
    n -= 1
    choice = choice_list[n]; proba_ok = choice.proba_ok
    enumerator_inclusive(choice_list, debug, n, result, current_proba * (1.0 - proba_ok), cumulator)
    enumerator_inclusive(choice_list, debug, n, result.clone << choice, current_proba * proba_ok, cumulator)
    cumulator
  end
end

def enumerator_exclusive(choice_list, debug=nil)
  null_proba = 1.0 - choice_list.inject(0.0) {|s,c| s += c.proba_ok}
  cumulator = each_propa_choices(null_proba, [], {}, debug)
  for i in 0..choice_list.size-1
    choice = choice_list[i]
    each_propa_choices(choice.proba_ok, [choice], cumulator, debug)
  end
  cumulator
end

def enumerator(choice_list, mode, debug=nil)
  e = case mode
    when :inclusive then enumerator_inclusive(choice_list, debug)
    when :exclusive then enumerator_exclusive(choice_list, debug)
  end
  (debug << "---------------------------") if debug
  e.each do |p, distributions|
    distributions_merged = Pikizi::Distribution.merge_by_weight(distributions)
    (debug << "#{t} =>  #{distributions_merged.join(', ')}") if debug
  end
  (debug << "---------------------------") if debug
  nil
end


# demo



class Choice
  attr_accessor :key, :proba_ok, :hash_pkey_weight

  def initialize(key, proba_ok, hash_pkey_weight)
    self.key = key
    self.proba_ok = proba_ok
    self.hash_pkey_weight = hash_pkey_weight
  end

  def to_s() "#{key}#{Pikizi::Root.as_percentage(proba_ok)}" end

  def generate_hash_pkey_weight() hash_pkey_weight end
  
end


def test_enumerator
  Pikizi::Root.compute_time do
    myputs "*************** inclusive ***************"
    choice_list = [ Choice.new("c1", 0.2, { :p1 => +1.0, :p2 => -1.0, :p3 => 0.5 }),
                    Choice.new("c2", 0.5, { :p1 => -1.0, :p2 => -0.5, :p3 => -1 }),
                    Choice.new("c3", 0.3, { :p1 => +1.0, :p3 => 0.5 })]
    enumerator(choice_list, :inclusive)


    myputs
    myputs "*************** exclusive ***************"
    choice_list = [ Choice.new("c1", 0.2, { :p1 => +1.0, :p2 => -1.0, :p3 => 0.5 }),
                    Choice.new("c2", 0.4, { :p1 => -1.0, :p2 => -0.5, :p3 => -1 }),
                    Choice.new("c3", 0.3, { :p1 => +1.0, :p3 => 0.5 })]
    enumerator(choice_list, :exclusive)
  end

end

def test_enumerator_integrated(debug = nil)
  debug = [] if debug
  knowledge = Pikizi::Knowledge.create_from_xml("cell_phones")

  Pikizi::Root.compute_time do

    knowledge.questions.each do |question|
      msgs_debug = question.enumerator(debug)
      msgs_debug.each {|msg_debug| puts msg_debug } if debug
    end
  end

  nil

end