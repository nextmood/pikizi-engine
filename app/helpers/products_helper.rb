module ProductsHelper

  def product_image(product, key='thumb', image_ids=nil)
    image_ids ||= product.image_ids.first
    if image_ids
      image_tag("/medias/datas/#{image_ids[key]}", :border => 0)
    else
      "no_image ???"
    end
  end

  
end
