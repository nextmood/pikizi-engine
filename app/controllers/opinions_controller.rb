require 'paginator'

class OpinionsController < ApplicationController

  # list all opinions for current knowledge
  def index
    @nb_opinions_per_page = 40
    @source_categories = params[:source_categories]
    @source_categories ||= Review.categories.collect { |category_name, weight| category_name }
    @state_names = params[:state_names]
    @state_names ||= Opinion.list_states

    select_options = { :category => @source_categories, :state => @state_names }
    @nb_opinions = Opinion.count(select_options)
    @pager = Paginator.new(@nb_opinions, @nb_opinions_per_page) do |offset, per_page|
      Opinion.all({:offset => offset, :limit => per_page, :order => 'written_at desc'}.merge(select_options))
    end
    @opinions = @pager.page(params[:page])
  end


end
