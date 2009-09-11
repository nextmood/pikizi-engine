class BackgroundsController < ApplicationController
  # GET /backgrounds
  # GET /backgrounds.xml
  def index
    @backgrounds = Background.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @backgrounds }
    end
  end

  # GET /backgrounds/1
  # GET /backgrounds/1.xml
  def show
    @background = Background.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @background }
    end
  end

  # return a background for a given product/feature/background_key
  # GET /product_background
  # GET /product_background/:product_key/:bgk_key/:model_key  (i.e. :feature_key == root)
  def product_background
    params[:product_key]
    params[:bgk_key]
    params[:model_key]
    params[:feature_key] || params[:model_key]
  end

  # return a list of backgrounds for a given product/feature
  # GET /product_backgrounds/:product_key/:model_key/:feature_key
  # GET /product_backgrounds/:product_key/:model_key  (i.e. :feature_key == root)
  def product_backgrounds

  end

  # return a background for a given feature/background_key
  # GET /knowledge_background/:bgk_key/:model_key/:feature_key
  # GET /knowledge_background/:bgk_key/:model_key  (i.e. :feature_key == root)
  def knowledge_background

  end

  # return a list of backgrounds for a given feature
  # GET /knowledge_backgrounds/:model_key/:feature_key
  # GET /knowledge_backgrounds/:model_key  (i.e. :feature_key == root)
  def knowledge_backgrounds

  end

  # GET /backgrounds/new
  # GET /backgrounds/new.xml
  def new
    @background = Background.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @background }
    end
  end

  # GET /backgrounds/1/edit
  def edit
    @background = Background.find(params[:id])
  end

  # POST /backgrounds
  # POST /backgrounds.xml
  def create
    @background = Background.new(params[:background])

    respond_to do |format|
      if @background.save
        flash[:notice] = 'Background was successfully created.'
        format.html { redirect_to(@background) }
        format.xml  { render :xml => @background, :status => :created, :location => @background }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @background.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /backgrounds/1
  # PUT /backgrounds/1.xml
  def update
    @background = Background.find(params[:id])

    respond_to do |format|
      if @background.update_attributes(params[:background])
        flash[:notice] = 'Background was successfully updated.'
        format.html { redirect_to(@background) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @background.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /backgrounds/1
  # DELETE /backgrounds/1.xml
  def destroy
    @background = Background.find(params[:id])
    @background.destroy

    respond_to do |format|
      format.html { redirect_to(backgrounds_url) }
      format.xml  { head :ok }
    end
  end

  # GET /backgrounds/1/thumbnail_150.jpg
  def thumbnail_150
    @background = Background.find(params[:id])
    respond_to do |format|
      format.jpg
    end
  end

end
