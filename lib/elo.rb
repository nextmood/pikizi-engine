# describe a ranking of items using comparison operators
# see http://zefredz.frimouvy.org/dotclear/index.php?2008/05/01/212-implementation-du-systeme-de-classement-elo-en-javascript
# see http://www.lifewithalacrity.com/2006/01/ranking_systems.html
#
class Elo

  def initialize(default_elo=1500)
    @elos = {}
    @default_elo = default_elo
    @min_elo, @max_elo = nil, nil
  end

  # return a ranking between 0.0 and 1.0 for a given product
  def get_elo01(p) (x = get_elo(p) and @min_elo and @max_elo) ? (x - @min_elo) / (@max_elo - @min_elo) : nil end 

  def for_each_p_elo01() @elos.each { |p, e| yield(p, get_elo01(p)) } end

  # call this method for each comparaison between 2 products (comparator = :best, :worse, :same)
  # elo rating will be updated
  def update_elo(p1, comparator, p2, author_reputation=1)
    p1_score = comparator2score(comparator)
    author_reputation.times do
      p1_elo, p2_elo = get_elo(p1), get_elo(p2)
      @elos[p1], @elos[p2] = new_elo(p1_elo, p2_elo, p1_score), new_elo(p2_elo, p1_elo, 1.0 - p1_score)
    end
    min, max = get_elo(p1), get_elo(p2)
    min, max = max, min  if min > max
    @min_elo = min if @min_elo.nil? or min < @min_elo
    @max_elo = max if @max_elo.nil? or max > @max_elo
  end

  # debugging purpose, display all products and their ranking
  def display() @elos.each { |p, elo| puts "elo=#{'%4d' % elo} elo01=#{'%3.1f' % get_elo01(p)} #{p}" }; true end

  private

  def get_elo(p) @elos[p] || @default_elo end

  def new_elo (p1_elo, p2_elo, p1_score)
    # compute the k factor
    k = (p1_elo < 2000.0 ? 32.0 : (p1_elo < 2400.0 ? 24.0 : 16.0))

    # compute the expected score for p1
    p1_score_expected = 1.0 / ( 1.0 + 10.0 ** (- ( p1_elo - p2_elo ) / 400.0) )

    # new elo for p1
    p1_elo + k * ( p1_score - p1_score_expected )
  end

  def comparator2score(status)
    case status
      when "better" then 1.0
      when "worse" then 0.0
      when "same" then 0.5
      else
        raise "bad score as status: #{status.inspect} (should be :better, :worse or :even)"
    end
  end

end

# ==========================================================================================
# Testing
# ==========================================================================================

def test(author_reputation=1, comparator="worse")
  e = Elo.new
  # update reviews
  e.update_elo('me', comparator, 'you', author_reputation)
  e.display
end