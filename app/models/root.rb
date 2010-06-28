

require 'xml'
require 'digest/md5'


# The root of all XML/objects of Pikizi (Feature, Question, Choice, User, Product, etc...)
class Root
  # abstract class

  # ---------------------------------------------------
  # utilities



  # always return a value between 0.0 and 1.0 for a given x ranging from min to max
  def self.rule3(x, min, max)
    y = Root.rule3_cache(x, Root.rule3_ab(min, max))
    puts "error x=#{x} y=#{y} min=#{min} max=#{max} ab=#{Root.rule3_ab(min, max).inspect}" unless y.in01?
    y
  end
  def self.rule3_cache(x, ab)
    ab.first * x + ab.last
  end
  def self.rule3_ab(min, max)
    a = 1.0 / (max - min)
    [ a , - a * min ]
  end

   
  # ---------------------------------------------------


  def generate_xml(top_node)
    tag_name = self.class.to_s
    if top_node.is_a?(XML::Document)
      top_node.root = (xml_node = XML::Node.new(tag_name))
    else
      top_node << (xml_node = XML::Node.new(tag_name))
    end

    class_keys = self.class.keys.collect(&:first).concat(self.class.associations.collect(&:first))
    xml_node['idurl'] = idurl if class_keys.include?("idurl")
    xml_node['label'] = label if class_keys.include?("label")

    xml_node['url_description'] = url_description if class_keys.include?("url_description") and url_description
    xml_node['url_image'] = url_image if class_keys.include?("url_image")  and url_image
    xml_node
  end


  def self.get_entries(path)
    Dir.new("#{path}").entries.inject([]) do |l, entry|
      (entry.has_prefix(".") or entry.has_prefix("..")) ? l : l << entry
    end
  end

  # to convert v.strftime(Root.default_datetime_format)
  def self.default_datetime_format() "%Y/%m/%d %H:%M:%S" end
  def self.default_date_format() "%Y/%m/%d" end

  def self.compute_time
    start = Time.now
    x = yield
    delta = Time.now - start
    puts "-----------------------------------------"
    puts "t=#{delta}, i.e. #{1. / delta}/s"
    puts "-----------------------------------------"
    x
  end

  def self.as_percentage(proba) "(#{'%d' % (proba * 100).round}%)" end

  # convert an object to an xml string
  def to_xml(a_idurl=nil)
    doc = XML::Document.new
    generate_xml(doc)
    doc.to_s(:indent => true)
  end

  def self.stars_html(value, max_rating)
    nb_stars_full = value.round
    s = ""
    max_rating.round.times do |i|
      s << Root.icon_star(i < nb_stars_full).clone
    end
    "<span title=\"rated #{ '%2.1f' % value } out of #{max_rating}\">#{s}</span>"
  end

  def self.icon_star(full=true) "<img src=\"/images/icons/star#{'_empty' unless full}.png\" border=\"0\" />" end

  def self.duration(nb=1)
    t = Time.now
    nb.times { yield }
    "nb_run=#{nb} average=#{(Time.now - t) / Float(nb)}"
  end



  
end




class String

  def has_prefix(prefix) self[0..prefix.size-1] == prefix end

  def remove_prefix(prefix) self[prefix.size..self.size-1] end

  def has_suffix(suffix) self[self.size-suffix.size..self.size-1] == suffix end

  def self.is_not_empty(s) s if s and s != "" end

  def extract_external_id
    if has_prefix(prefix = "http://www.facebook.com/profile.php?id=")
      [:facebook, String.is_not_empty(remove_prefix(prefix))]
    elsif has_prefix(prefix = "http://www.twitter.com/profile.php?id=")
      [:twitter, String.is_not_empty(remove_prefix(prefix))]
    end
  end

  def ensure_size(s)
    if size < s
      self << " " * (s - size)
      # complete with xxx
    else
      self[0, s]  
    end
  end

  def find_between(c1, c2)
    l = []; x = 0
    while x < size and ic1 = index(c1, x) and ic2 = index(c2, ic1 + 1)
      l << self[ic1+1, ic2 - ic1 - 1]
      x = ic2 + 1
    end
    l
  end

  # remove all html tags from a string and carriage return also
  def remove_tags_html() self.gsub(%r{</?[^>]+?>}, '').gsub("\r\n", ' ') end



  # the Levenshtein Distance (see http://www.informit.com/articles/article.aspx?p=683059&seqNum=36)
  # "ACUGAUGUGA".levenshtein("AUGGAA")    # 9
  # "pennsylvania".levenshtein("pencilvaneya")    # 7
  # "abcd".levenshtein("abcd")    # 0
  def levenshtein(other, ins=2, del=2, sub=1)
    # ins, del, sub are weighted costs
    return nil if self.nil?
    return nil if other.nil?
    dm = []        # distance matrix

    # Initialize first row values
    dm[0] = (0..self.length).collect { |i| i * ins }
    fill = [0] * (self.length - 1)

    # Initialize first column values
    for i in 1..other.length
      dm[i] = [i * del, fill.flatten]
    end

    # populate matrix
    for i in 1..other.length
      for j in 1..self.length
    # critical comparison
        dm[i][j] = [
             dm[i-1][j-1] +
               (self[j-1] == other[i-1] ? 0 : sub),
                 dm[i][j-1] + ins,
             dm[i-1][j] + del
       ].min
      end
    end

    # The last value in matrix is the
    # Levenshtein distance between the strings
    dm[other.length][self.length]
  end

  def similar_leveinstein(dictionnary, threshold=10, ins=2, del=2, sub=1)
    dictionnary.inject([]) do |l, word_in_dictionnary|
       ((d = levenshtein(word_in_dictionnary, ins, del, sub)) < threshold) ? l << [word_in_dictionnary, d] : l
    end
  end

end

class Float
  def in01?() self >= 0.0 and self <= 1.0 end
end




# extented array
class Array

  # with basic statistical functions

  def stat_sum() inject(0.0) { |s, x| (x.nil? or x.nan?) ? s : s + x } end
  def stat_mean() stat_sum / size.to_f end
  def stat_standard_deviation()
    m = stat_mean
    begin
      Math.sqrt((inject(0.0) { |s, x| x.nan? ? s : s + (x - m)**2 } / size.to_f))
    rescue Exception => e
      raise "error #{e.message} x=#{self.inspect}"
      0.0
    end
  end

  def nb_unique() inject([]) { |l, x| l.include?(x) ? l : l << x }.size  end

  # yield all all possible combinations in an array
  # and return the number of combination (empty set count for one)
  def self.combinatorial(tail, empty_count, &block) self.combinatorial_bis(tail, empty_count, [], 0, &block) end
  def self.combinatorial_bis(tail, empty_count, elt_set, x, &block)
    if tail.size == 0
      if elt_set.size > 0 or empty_count
        block.call(elt_set)
        x += 1
      else
        x
      end
    else
      new_tail = tail.clone
      first_elt = new_tail.shift
      x = self.combinatorial_bis(new_tail, empty_count, elt_set, x, &block)
      x = self.combinatorial_bis(new_tail, empty_count, elt_set.clone << first_elt, x, &block)
    end
    x
  end

end

# extended hash
class Hash

  def to_date() Date.new(self["year"].to_i, self["month"].to_i, self["day"].to_i)  end

end
