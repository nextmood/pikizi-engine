class MediasController < ApplicationController

  def show
    @media_id = params[:id]
    @datas = Media.datas(@media_id)
  end

  def datas
    datas = Media.datas(params[:id])
    send_data datas.read, :type => datas.content_type, :disposition => 'inline'    
  end

  # post /medias/create
  def create
    # this is a new media
    media_file = params[:media_file]

    # 2 mega max
    if Media.mime_type_valid?(media_file.content_type) and media_file.length < 2000000
      flash[:notice] = "Media sucessufuly created"
      media_ids = Media.create(media_file.read, media_file.original_filename, media_file.content_type, { :description => "test by fpa"} )
      puts "what the fuck media_id=#{media_ids.inspect}"
      redirect_to  "/medias/show/#{media_ids["main"]}"
    else
      flash[:notice] = "ERROR Media was not created #{media_file.content_type}=#{Media.mime_type_valid?(media_file.content_type)} size=#{media_file.length }"
      render(:action => "new")
    end

  end

  def new() end
  
end
