module OffersHelper

  def offer_title(offer)
    s = (x = offer.merchant.label) == "other" ? offer.label : "#{x} #{offer.label}"
    s = link_to(s, offer.url) if offer.url and offer.url != ""
    s
  end
  
end
