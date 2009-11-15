
def build_distributions_inclusive(choice_list, debug=nil, n=nil, result=[], current_proba=1.0, cumulator={})
  n ||= choice_list.size
  if n == 0
    cumulator = each_propa_choices(current_proba, result, cumulator, debug)
  else
    n -= 1
    choice = choice_list[n]; proba_ok = choice.proba_ok
    build_distributions_inclusive(choice_list, debug, n, result, current_proba * (1.0 - proba_ok), cumulator)
    build_distributions_inclusive(choice_list, debug, n, result.clone << choice, current_proba * proba_ok, cumulator)
    cumulator
  end
end

def build_distributions_exclusive(choice_list, debug=nil)
  null_proba = 1.0 - choice_list.inject(0.0) {|s,c| s += c.proba_ok}
  cumulator = each_propa_choices(null_proba, [], {}, debug)
  for i in 0..choice_list.size-1
    choice = choice_list[i]
    each_propa_choices(choice.proba_ok, [choice], cumulator, debug)
  end
  cumulator
end

def build_distributions(choice_list, mode, debug=nil)
  e = case mode
    when :inclusive then build_distributions_inclusive(choice_list, debug)
    when :exclusive then build_distributions_exclusive(choice_list, debug)
  end
  (debug << "---------------------------") if debug
  e.each do |p, distributions|
    distributions_merged = DistributionAtom.merge_by_weight(distributions)
    (debug << "#{t} =>  #{distributions_merged.join(', ')}") if debug
  end
  (debug << "---------------------------") if debug
  nil
end


# demo



class Choice
  attr_accessor :idurl, :proba_ok, :hash_pidurl_weight

  def initialize(idurl, proba_ok, hash_pidurl_weight)
    self.idurl = idurl
    self.proba_ok = proba_ok
    self.hash_pidurl_weight = hash_pidurl_weight
  end

  def to_s() "#{idurl}#{Root.as_percentage(proba_ok)}" end

  def generate_hash_pidurl_weight() hash_pidurl_weight end
  
end


def test_build_distributions
  Root.compute_time do
    myputs "*************** inclusive ***************"
    choice_list = [ Choice.new("c1", 0.2, { :p1 => +1.0, :p2 => -1.0, :p3 => 0.5 }),
                    Choice.new("c2", 0.5, { :p1 => -1.0, :p2 => -0.5, :p3 => -1 }),
                    Choice.new("c3", 0.3, { :p1 => +1.0, :p3 => 0.5 })]
    build_distributions(choice_list, :inclusive)


    myputs
    myputs "*************** exclusive ***************"
    choice_list = [ Choice.new("c1", 0.2, { :p1 => +1.0, :p2 => -1.0, :p3 => 0.5 }),
                    Choice.new("c2", 0.4, { :p1 => -1.0, :p2 => -0.5, :p3 => -1 }),
                    Choice.new("c3", 0.3, { :p1 => +1.0, :p3 => 0.5 })]
    build_distributions(choice_list, :exclusive)
  end

end

def test_build_distributions_integrated(debug = nil)
  debug = [] if debug
  knowledge = Knowledge.create_from_xml("cell_phones")

  Root.compute_time do

    knowledge.questions.each do |question|
      msgs_debug = question.build_distributions(debug)
      msgs_debug.each {|msg_debug| puts msg_debug } if debug
    end
  end

  nil

end

