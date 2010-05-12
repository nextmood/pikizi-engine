# this is a collection of the weight distribution for each product (merging choices according to proba)
# for a given question
# return for this question, a hash (product_idurl => Distribution)
# for example: p1 -> [DistributionAtom(20%,-1.0), DistributionAtom(50%,0.5), DistributionAtom(30%,0.2)]
# meaning is: if this question is asked, there is a probability of
# 20% of product p1 getting a -1.0, 50% of getting 0.5 etc...
# compute also the minimum/maximum weight that this product can get
class ProductsDistribution

  attr_accessor :hash_pidurl_distribution, :question

  def initialize(question)
    @hash_pidurl_distribution = {}
    @question = question
    question.is_choice_exclusive ? initialize_exclusive : initialize_inclusive
  end

  def collect(&block) @hash_pidurl_distribution.collect(&block) end

  # this function  returns a measure of how the answer to a question will discrimate
  # a set of products
  # the measure is a 3-upple made of [standard deviation, nb product, average weight]
  def discrimination(user, product_idurls)
    weights = @hash_pidurl_distribution.inject([]) do |l, (pidurl, distribution)|
      l << distribution.weighted_average * question.weight if product_idurls.include?(pidurl)
      l
    end
    if (size = weights.size) == 0
        [0.0, 0 , 0.0]
    elsif size == 1
        [0.0, 1, weights.first]
    else
        [weights.stat_standard_deviation, weights.size, weights.stat_mean]
    end
  end

  def get_distribution4product_idurl(product_idurl) @hash_pidurl_distribution[product_idurl] end
  # private below


  def initialize_inclusive
    ProductsDistribution.combinatorial_weight(question.all_choices) do |selected_choices, hash_product_idurl_2_weight, choice_probability|
      hash_product_idurl_2_weight.each do |pidurl, weight|
        distribution = (hash_pidurl_distribution[pidurl] ||= Distribution.new)
        distribution.add(weight, choice_probability)
      end
    end
  end

  def initialize_exclusive
    question.all_choices.each do |choice|
      choice_probability = choice.proba_ok
      choice.hash_product_idurl_2_weight.each do |pidurl, weight|
        distribution = (hash_pidurl_distribution[pidurl] ||= Distribution.new)
        distribution.add(weight, choice_probability)
      end
    end
  end


  def self.combinatorial_weight(choices, &block)
    hash_combinationkey2hash_product_idurl_2_weight = {}

    Array.combinatorial(choices, false) do |combination_choices|
      # combination is a list of choices
      choice_probability = choices.inject(1.0) { |x, c| x *= (combination_choices.include?(c) ? c.proba_ok : c.proba_ko) }

      combination_choices_new = combination_choices.clone
      combination_key = ProductsDistribution.compute_combination_key(combination_choices_new)
      first_choice = combination_choices_new.shift
      hash_product_idurl_2_weight = first_choice.hash_product_idurl_2_weight
      hash_product_idurl_2_weight += hash_combinationkey2hash_product_idurl_2_weight[ProductsDistribution.compute_combination_key(combination_choices_new)] if combination_choices_new.size > 0
      hash_combinationkey2hash_product_idurl_2_weight[combination_key] = hash_product_idurl_2_weight
      block.call(combination_choices, hash_product_idurl_2_weight, choice_probability)
    end
  end

  def self.compute_combination_key(combination_choices) combination_choices.collect(&:idurl).join end




end

# Distribution is a collection of weight/proba for a given product/question
class Distribution
  attr_accessor :hash_weight_probability

  def initialize()
    @hash_weight_probability = {}
  end

  def add(weight, probability)
    @hash_weight_probability[weight] ||= 0.0
    @hash_weight_probability[weight] += probability
  end

  def weighted_average
    @hash_weight_probability.inject(0.0) { |wa, (weight, probability)| wa += (probability * weight) }
  end


  def to_s()
    "Distribution=[" << @hash_weight_probability.collect {|weight, probability| "#{weight} => #{Root.as_percentage(probability)}"}.join(", ") << "]"
  end


end

