# this a hash between Product Idurl and weight
class Pidurl2Weight
  attr_accessor :hash_pidurl_weight

  def initialize(hash_pidurl_weight={})
    @hash_pidurl_weight = hash_pidurl_weight
  end

  #def add(product_idurl, weight) @hash_pidurl_weight[product_idurl] = weight end

#  def +(other_hash)
#    other_hash.hash_pidurl_weight.each do |pidurl, weight|
#      @hash_pidurl_weight[pidurl] ||= 0.0
#      @hash_pidurl_weight[pidurl] += weight
#    end
#    self
#  end

  # define a weighted sum operator
  def sum(pidurl2weight, probability=1.0)
    pidurl2weight.each do |pidurl, weight|
      @hash_pidurl_weight[pidurl] ||= 0.0
      @hash_pidurl_weight[pidurl] += weight * probability if weight > 0.0
    end
    self
  end

  def duplicate() Pidurl2Weight.new(hash_pidurl_weight.clone) end

  def *(multiplicator)
    @hash_pidurl_weight.each { |pidurl, weight| @hash_pidurl_weight[pidurl] = weight * multiplicator }
    self
  end

  # return the weight for a given product_idurl
  def [](pidurl) @hash_pidurl_weight[pidurl] || 0.0 end

  # remove all zero values
  def compact!
    @hash_pidurl_weight.each { |key, value| @hash_pidurl_weight.delete(key) if value == 0.0 }
  end

  def normalize!
    min, max = min_max
    if min and max
      if min == max
        @hash_pidurl_weight.each { |key, value| @hash_pidurl_weight[key] = 0.0 }
      else
        ab = Root.rule3_ab(min, max)
        @hash_pidurl_weight.each { |key, value| @hash_pidurl_weight[key] = Root.rule3_cache(@hash_pidurl_weight[key], ab) }
        check_01
      end
    end
    self
  end

  def only_pidurls!(pidurls)
    @hash_pidurl_weight.delete_if { |pidurl, v| !pidurls.include?(pidurl) }if pidurls
    self
  end


  def to_s
    "Pidurl2Weight[" << @hash_pidurl_weight.collect { |pidurl, weight| "#{pidurl}:#{'%3.1f' % weight}" }.join(', ') << "]"
  end

  def collect(&block) @hash_pidurl_weight.collect(&block) end

  # proxy
  def each(&block) @hash_pidurl_weight.each(&block) end

  def min_max
    @hash_pidurl_weight.inject([nil, nil]) do |(min, max), (product_idurl, weight)|
      [ ((min.nil? or weight < min) ? weight : min), ((max.nil? or weight > max) ? weight : max) ]
    end
  end

  def check_01
    raise "not in 01" if  @hash_pidurl_weight.any? { |p, w| w < 0.0 or w > 1.0 }
  end

  

  def set(pidurl, value) @hash_pidurl_weight[pidurl] = value end

  # mongodb driver
  # see http://groups.google.com/group/mongomapper/browse_thread/thread/d97afeac5b9ea1bf/2ffcd2d4cd609ac2?lnk=gst&q=to_mongo#2ffcd2d4cd609ac2

  # convert value to a mongo safe data type
  def self.to_mongo(value)
    value.is_a?(Pidurl2Weight) ? value.hash_pidurl_weight : value
  end

  # convert value from a mongo safe data type to your custom data type
  def self.from_mongo(value)
    value.is_a?(Hash) ? new(value) : value
  end


end
