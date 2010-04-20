class ProductsController < ApplicationController

  def index
    @products = Product.all
  end


  def show
    @product = Product.first(:idurl => params[:product_idurl])
    @current_knowledge.link_back
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render(:xml => @product) }
    end
  end

  # -------------------------------------------------------------------------------------------
  # Creating / edting product header
  # -------------------------------------------------------------------------------------------

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

    # -------------------------------------------------------------------------------------------
  # handling the product header
  # -------------------------------------------------------------------------------------------

  def update_header
    product = Product.find(params[:id])
    product.label = params[:label] if params[:label] != ""
    product.url = params[:url] if params[:url] != ""
    media_file = params[:media_file] == "" ? nil : params[:media_file]
    puts "media_file.content_type=#{media_file.content_type}" if media_file
    # 2 mega max
    if media_file and Media::MediaText.mime_type_valid?(media_file.content_type) and media_file.length < 2000000
      Media.delete(product.description_id) if product.description_id # delete previous one if needed
      product.description_id = Media::MediaText.create(media_file)
    end
    product.save
    redirect_to  "/products/#{product.idurl}"
  end

  # -------------------------------------------------------------------------------------------
  # Similar products.......
  # -------------------------------------------------------------------------------------------

  # this is a rjs
  def add_similar_product
    product  = Product.find(params[:id])
    similar_product  = Product.find(params[:similar_product_id])
    product.add_similar_product(similar_product)
    render :update do |page|
      page.replace("similar_products_#{product.id}", :partial => "/products/similar_products", :locals => { :product => product })
    end
  end

  def delete_similar_product
    puts "****** " << params.inspect
    product  = Product.find(params[:id])
    similar_product  = Product.find(params[:similar_product_id])
    product.delete_similar_product(similar_product)
    render :update do |page|
      page.replace("similar_products_#{product.id}", :partial => "/products/similar_products", :locals => { :product => product })
    end
  end



  # -------------------------------------------------------------------------------------------
  # Image management
  # -------------------------------------------------------------------------------------------

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


  # -------------------------------------------------------------------------------------------
  # Specification
  # -------------------------------------------------------------------------------------------


  # this is a rjs
  # return the form to edit a feature
  def edit_specification
    product = Product.find(params[:id])
    specification = Specification.find(params[:specification_id])
    render :update do |page|
      page.replace_html("div_specification_#{specification.id}", :partial => "/specifications/edit",
                  :locals => { :product => product, :specification => specification })
    end
  end

    # this is a rjs
  # return the form to edit a feature's value
  def edit_specification_value
    product = Product.find(params[:id])
    specification = Specification.find(params[:specification_id])
    render :update do |page|
      page.replace_html("div_specification_#{specification.id}", :partial => "/specifications/edit_value",
                  :locals => { :product => product, :specification => specification })
    end
  end

  def cancel_specification
    product = Product.find(params[:id])
    specification = Specification.find(params[:specification_id])
    render :update do |page|
      page.replace_html("div_specification_#{specification.id}", "")
    end
  end

  def delete_specification
    product = Product.find(params[:id])
    specification = Specification.find(params[:specification_id])
    specification.destroy
    redirect_to "/products/#{product.idurl}"
  end

  # -------------------------------------------------------------------------------------------
  # Dimension management
  # -------------------------------------------------------------------------------------------

  # editing the dimension
  # this isa remote form
  def edit_dimension
    dimension_id = Mongo::ObjectID.from_string(params[:id])
    product = Product.find(params[:product_id])
    dimension = @current_knowledge.dimensions.detect { |d| d.id == dimension_id }
    params[:dimension][:parent_id] = Mongo::ObjectID.from_string(params[:dimension][:parent_id])
    dimension.update_attributes(params[:dimension])
    render :update do |page|
      page.replace_html("list_specifications", :partial => "dimensions",
         :locals => { :knowledge => @current_knowledge, :dimensions => [@current_knowledge.dimension_root], :product => product })
    end
  end

  # this si a rjs
  def edit_dimension_open
    dimension_id = Mongo::ObjectID.from_string(params[:id])
    dimension = @current_knowledge.dimensions.detect { |d| d.id == dimension_id }
    raise "***** error #{dimension_id.inspect} == #{dimension.inspect}" unless dimension
    product = Product.find(params[:product_id])

    render :update do |page|    
      page.replace_html("div_dimension_extra_#{dimension.id}", :partial => "/products/dimension_edit",
         :locals => { :knowledge => @current_knowledge, :dimension => dimension, :product => product })
    end
  end

  # this is a rjs
  def create_dimension_open
    dimension = Dimension.new(:parent_id => @current_knowledge.dimension_root.id)
    product = Product.find(params[:id])
    render :update do |page|
      page.replace_html("editor_create_dimension", :partial => "/products/dimension_create",
         :locals => { :dimension => dimension, :product => product, :knowledge => @current_knowledge})
    end
  end

  # this a rjs
  def create_dimension
    product = Product.find(params[:id])
    params[:dimension][:parent_id] = Mongo::ObjectID.from_string(params[:dimension][:parent_id])
    new_dimension = @current_knowledge.dimensions.create(params[:dimension])
    puts "adding dimension id=#{new_dimension.id}"
    render :update do |page|
      page.replace_html("list_specifications", :partial => "dimensions",
         :locals => { :knowledge => @current_knowledge, :dimensions => [@current_knowledge.dimension_root], :product => product })
    end
  end
  
  # this a rjs  (for cancel)
  def redisplay_dimension
    product = Product.find(params[:id])
    render :update do |page|
      page.replace_html("list_specifications", :partial => "dimensions",
         :locals => { :knowledge => @current_knowledge, :dimensions => [@current_knowledge.dimension_root], :product => product })
    end
  end

  # this is a rjs, gave explanation about how a dimension is computed
  def dimension_explanation
    weight_elo = 0.5; weight_rating = 0.5

    all_products = @current_knowledge.products
    product = all_products.detect { |p| p.id.to_s == params[:id] }
    raise "no product" unless product
    dimension = Dimension.find(params[:dimension_id])

    ratings, comparaisons = dimension.compute_aggregation_ratings_comparaisons(product)
    hash_product_2_category_average_rating01 = dimension.compute_hash_product_2_category_average_rating01(ratings, all_products, product)
    hash_product_2_average_rating01 = dimension.compute_hash_product_2_average_rating01(hash_product_2_category_average_rating01, product)
    elo = dimension.compute_elo(comparaisons, all_products)
    hash_product_2_average_sub_dimensions = dimension.compute_hash_product_2_average_sub_dimensions(all_products, product)
    hash_pid_2_average_mixed = dimension.combine_rating_elo_sub_automatic(hash_product_2_average_rating01, elo, hash_product_2_average_sub_dimensions, product)
    render :update do |page|
      page.replace_html("div_explanation_dimension_#{dimension.id}", :partial => "/products/dimension_explanation",
         :locals => { :dimension => dimension, :product => product, :ratings => ratings, :comparaisons =>  comparaisons,
                      :hash_product_2_category_average_rating01 => hash_product_2_category_average_rating01,
                      :hash_product_2_average_rating01 => hash_product_2_average_rating01,
                      :elo => elo,
                      :hash_pid_2_average_mixed => hash_pid_2_average_mixed,
                      :hash_product_2_average_sub_dimensions => hash_product_2_average_sub_dimensions })
    end
  end

  def dimension_explanation_close
    render :update do |page|
      page.replace_html("div_explanation_dimension_#{params[:id]}", "")
    end
  end

  def compute_aggregation
    product = Product.find(params[:id])
    product.knowledge.compute_aggregation
    redirect_to("/products/#{product.idurl}")
  end
  
  # -------------------------------------------------------------------------------------------
  # Usages
  # -------------------------------------------------------------------------------------------

  def usages

  end
end
