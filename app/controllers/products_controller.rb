class ProductsController < ApplicationController

  def index
    @products = Product.all
  end


  def show
    @product = Product.first(:idurl => params[:product_idurl])
    @knowledge = @product.knowledge.link_back
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render(:xml => @product) }
    end
  end

  # get /products/create_byidurl/knowledge_idurl
  def create_byidurl
    @messages_creating_product_by_idurl = nil
    @product = nil
    @knowledge = Knowledge.first(:idurl => params[:id])
    if new_idurl = params[:new_idurl] and new_idurl.size > 7

      if Product.first(:idurl => new_idurl)
        @messages_creating_product_by_idurl = "<span style=\"color:red;\">#{new_idurl} already exists</span>"
      else
        @product = @knowledge.products.create(:idurl => new_idurl, :label => new_idurl)
        @messages_creating_product_by_idurl = "<span style=\"color:green;\">product with idurl=#{new_idurl.inspect} created, please edit below</span>"
      end
    else
      @messages_creating_product_by_idurl = "<span style=\"color:red;\">idurl=#{new_idurl.inspect} is wrong</span>"
    end
    @product ||= Product.find(params[:product_id])
    render(:action => "show")
  end

  # post /products/update/id
  def update
    @product = Product.find(params[:id])
    raise "error no product #{params[:id]}" unless @product
    @product.update_attributes(params[:product])
    @knowledge = @product.knowledge

    if @product.save
      flash[:notice] = "Product sucessufuly updated"
      redirect_to  "/products/#{@product.idurl}"
    else
      flash[:notice] = "ERROR Product was not upodated"
      render(:action => "edit")
    end
  end

  def delete_main_image
    product = Product.find(params[:id])
    image_ids_to_delete = product.image_ids.detect { |h| h['main'].to_s == params[:main_image_id] }
    product.image_ids.delete(image_ids_to_delete)
    product.save    
    image_ids_to_delete.each { |key, media_id| Media.delete(media_id) }
    redirect_to  "/products/#{product.idurl}"
  end

  def add_image
    product = Product.find(params[:id])
    media_file = params[:media_file]

    # 2 mega max
    if Media::MediaImage.mime_type_valid?(media_file.content_type) and media_file.length < 2000000
      flash[:notice] = "Media sucessufuly created"
      media_ids = Media::MediaImage.create(media_file.read, media_file.original_filename, media_file.content_type )
      product.image_ids << media_ids
      product.save
      redirect_to  "/products/#{product.idurl}"
    else
      flash[:notice] = "ERROR Media was not created #{media_file.content_type}=#{Media.mime_type_valid?(media_file.content_type)} size=#{media_file.length }"
      render(:action => "new")
    end

  end

  # this is a rjs
  # return the form to edit a feature
  def edit_feature
    product = Product.find(params[:id])
    knowledge = product.knowledge
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    render :update do |page|
      page.replace_html("div_#{feature.idurl}", :partial => "/products/edit_feature",
                  :locals => { :product => product, :knowledge => knowledge, :feature => feature })
    end
  end

    # this is a rjs
  # return the form to edit a feature's value
  def edit_value
    product = Product.find(params[:id])
    knowledge = product.knowledge
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    render :update do |page|
      page.replace_html("div_#{feature.idurl}", :partial => "/products/edit_value",
                  :locals => { :product => product, :knowledge => knowledge, :feature => feature })
    end
  end

  def cancel_feature
    product = Product.find(params[:id])
    knowledge = product.knowledge
    feature = knowledge.get_feature_by_idurl(params[:feature_idurl])
    render :update do |page|
      page.replace_html("div_#{feature.idurl}", "")
    end
  end

  # -------------------------------------------------------------------
  # handling the product header

  def update_header
    product = Product.find(params[:id])
    product.label = params[:label] if params[:label] != ""
    product.url = params[:url] if params[:url] != ""
    media_file = params[:media_file] == "" ? nil : params[:media_file]
    puts "media_file.content_type=#{media_file.content_type}" if media_file
    # 2 mega max
    if media_file and Media::MediaText.mime_type_valid?(media_file.content_type) and media_file.length < 2000000
      Media.delete(media_id) if product.description_id # delete previous one if needed
      product.description_id = Media::MediaText.create(media_file)
    end
    product.save
    redirect_to  "/products/#{product.idurl}"
  end

  # this is a rjs
  def add_similar_product
    product = Product.find(params[:id])
    similar_product_id = Mongo::ObjectID.from_string(params[:similar_product_id])
    product.similar_product_ids ||= []
    unless product.similar_product_ids.include?(similar_product_id)
      product.similar_product_ids = (product.similar_product_ids << similar_product_id)
      product.save
    end
    render :update do |page|
      page.replace("similar_products_#{product.id}", :partial => "/products/similar_products", :locals => { :product => product })
    end
  end

  def delete_similar_product
    product = Product.find(params[:id])
    similar_product_id = Mongo::ObjectID.from_string(params[:similar_product_id])
    product.similar_product_ids ||= []
    if product.similar_product_ids.include?(similar_product_id)
      product.similar_product_ids.delete(similar_product_id)
      product.save
    end
    render :update do |page|
      page.replace("similar_products_#{product.id}", :partial => "/products/similar_products", :locals => { :product => product })
    end
  end
  # -------------------------------------------------------------------
end
