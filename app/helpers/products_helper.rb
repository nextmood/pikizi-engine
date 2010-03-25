module ProductsHelper

  def product_image(product, key='thumb', image_ids=nil)
    image_ids ||= product.image_ids.first
    image_tag("/medias/datas/#{image_ids[key]}", :border => 0)
  end

  
end
