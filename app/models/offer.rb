


# Availability is a set of valid prices by merchant for this product
class Offer
  include MongoMapper::Document

  key :_type, String # class management
  
  key :product_ids, Array # an array of products Ids
  belongs_to :product

  key :merchant_id
  belongs_to :merchant

  key :label, String

  key :amount, Float
  key :offer_url, String
  key :valid_from, DateTime
  key :valid_until, DateTime

  key :conditions, String

  timestamps!

  def self.import_all()

    Merchant.delete_all
    merchant_ids = ["other", "amazon", "bestbuy", "radioshack"].inject({}) do |h, merchant_label|
      h[merchant_label] = Merchant.create(:label => merchant_label).id
      h 
    end

    Offer.delete_all
    knowledge = Knowledge.first.link_back
    
    features_idurls = ["unsubsidized_price",
                       "special_carrier_promotion",
                       "subsidized_price",
                          "plan_requirements",
                          "minimum_plam",
                          "data_plan",
                          "minimum_subcription",
                          "activation_fee",
                          "early_cancellation",
                          "carrier_url",
                        "amazon_price", "amazon_url",
                        "bestbuy_price", "bestbuy_url",
                        "radioshack_price", "radioshack_url"]

    features = features_idurls.inject({}) {|h, f_idurl| h[f_idurl] = knowledge.get_feature_by_idurl(f_idurl); h }

    valid_from = Time.now - 100 * 24 * 3600
    valid_until = Time.now + 100 * 24 * 3600

    Product.all.each do |product|

      if amount = features["unsubsidized_price"].get_value(product)
        Price.create(:product_ids => [product.id], :label => "unsubsidized", :merchant_id => merchant_ids["other"], :amount => amount, :valid_from => valid_from, :valid_until => valid_until)
      end

      if amount = features["special_carrier_promotion"].get_value(product)
        Rebate.create(:product_ids => [product.id], :label => "special carrier promotion", :merchant_id => merchant_ids["other"], :amount => amount, :valid_from => valid_from, :valid_until => valid_until)
      end

      if amount = features["subsidized_price"].get_value(product)
        conditions = ["minimum_plam", "data_plan", "minimum_subcription", "activation_fee", "early_cancellation"].inject([]) do |l, c|
          (x = features[c].get_value(product)) ? l << "#{c} => #{'%.2f' % x}$" : l
        end 
        Price.create(:product_ids => [product.id], :label => "subsidized price", :merchant_id => merchant_ids["other"], :amount => amount,
                     :valid_from => valid_from, :valid_until => valid_until, :conditions => conditions.join(', '),
                     :url => features["carrier_url"].get_value(product))
      end

      ["amazon", "bestbuy", "radioshack"].each do |merchant|
        if amount = features["#{merchant}_price"].get_value(product)
          Price.create(:product_ids => [product.id], :merchant_id => merchant_ids[merchant], :amount => amount,
                     :valid_from => valid_from, :valid_until => valid_until,
                     :url => features["#{merchant}_url"].get_value(product))    
        end
      end

    end

    true
  end

end

class Price < Offer

  # return the min,max price for a product
  def self.min_max(product_id)
    amounts = self.all(:product_ids => product_id).collect(&:amount)
    [amounts.min, amounts.max]
  end

end

class Rebate < Offer

end