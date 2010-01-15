module HomeHelper

  def simpler_rating_label(rating_label)
    simpler_rating_label = rating_label.gsub('Rating', '').strip
    simpler_rating_label = "Overall" if simpler_rating_label == ""
    simpler_rating_label
  end

end