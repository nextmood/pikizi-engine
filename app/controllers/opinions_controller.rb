require 'paginator'

class OpinionsController < ApplicationController

  # list all opinions for current knowledge
  def index
    @review_label = params[:review_label]
    @opinion_sub_classes = params[:opinion_sub_classes]
    if related_product_label = params[:search] and related_product_label = params[:search][:related_product]
      @related_product = Product.first(:label => related_product_label)
    end
    @max_nb_opinions = params[:max_nb_opinions] || 100
    @date_oldest = if date_oldest = params[:date_oldest]
      Date.new(Integer(date_oldest["year"]), Integer(date_oldest["month"]), Integer(date_oldest["day"]))
    else
      Date.today - 90
    end
    
    @output_mode = params[:output_mode] || "standard"
    @source_categories = params[:source_categories]
    @source_categories ||= Review.categories.collect { |category_name, weight| category_name }
    @state_names = params[:state_names]
    @state_names ||= Opinion.list_states.collect(&:first)


    @opinion_sub_classes  = params[:opinion_sub_classes]
    @opinion_sub_classes ||= Opinion.subclasses_and_labels.collect(&:first)

    where_clauses = []
    where_clauses << "this.review.filename_xml.match(/#{@review_label}/i)" if @review_label

    select_options = { "_type" => @opinion_sub_classes,
                       :category => @source_categories,
                       :state => @state_names,
                       :limit => @max_nb_opinions,
                       :written_at => { '$gt' => @date_oldest.to_time },
                       :order => "written_at DESC"  }
    select_options["product_ids"] = @related_product.id if @related_product

    # puts "selection options=#{select_options.inspect}"
    @opinions = Opinion.all(select_options)
    @nb_opinions = @opinions.size
    if ["by_review"].include?(@output_mode)
      @opinions = @opinions.group_by(&:review_id).inject({}) do |h, (review_id, opinions)|
        h[review_id] = opinions.group_by(&:paragraph_id); h
      end
    end

    if @output_mode == "xml"
      oc = Ocollection.new_with_opinions(@current_user.rpx_username, "xml output #{Time.now}", @opinions)
      puts oc.class
      puts oc.to_xml.inspect
      render(:xml => oc )
    else
      # index.html.erb
    end


  end

  def import
    @ocollections = Ocollection.all(:limit => 100)
    # @product = Product.find(params[:product_id])
    @product = Product.first
  end


  def import_process
    if filename_xml = (params[:filename_xml] == "" ? nil : params[:filename_xml])
      if filename_xml.content_type == "text/xml"
        #begin
          flash[:notice] = ""
          flash[:notice] << "filename_xml.length=#{filename_xml.length}<br/>"
          label_ocollection = filename_xml.original_filename unless label_ocollection and label_ocollection != ""
          Ocollection.import(@current_knowledge, @current_user.rpx_username, filename_xml)
        #rescue  Exception => e
          #flash[:notice] = "ERROR while importing #{e.message}"
        #end
      else
        flash[:notice] = "file should have a content/type= \"text/xml\", WRONG: #{filename_xml.content_type.inspect}"
      end
    else
      flash[:notice] = "I need a file to import !"
    end
    redirect_to "/opinions/import"
  end

  def auto_complete_for_search_related_product
    input = params[:search][:related_product]
    render(:inline => "<ul>" << Product.similar_to(input).collect { |l| "<li>#{l}</li>"}.join  << "</ul>")
  end

end
