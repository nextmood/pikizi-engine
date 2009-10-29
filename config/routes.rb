ActionController::Routing::Routes.draw do |map|

  map.resources :backgrounds, :member => { :thumbnail_150 => :get  }


  # GET /medias/:knowledge_idurl/model/[:feature_idurl]
  # GET /medias/:knowledge_idurl/product/:product_idurl/[:feature_idurl]
  # GET /medias/:knowledge_idurl/question/:question_idurl/[:choice_idurl]
  map.connect '/medias/:knowledge_idurl/model', :controller => 'knowledges', :action => 'medias', :selector => :model
  map.connect '/medias/:knowledge_idurl/model/:feature_idurl', :controller => 'knowledges', :action => 'medias', :selector => :model
  map.connect '/medias/:knowledge_idurl/product/:product_idurl', :controller => 'knowledges', :action => 'medias', :selector => :product
  map.connect '/medias/:knowledge_idurl/product/:product_idurl/:feature_idurl', :controller => 'knowledges', :action => 'medias', :selector => :product
  map.connect '/medias/:knowledge_idurl/question/:question_idurl', :controller => 'knowledges', :action => 'medias', :selector => :question
  map.connect '/medias/:knowledge_idurl/question/:question_idurl/:choice_idurl', :controller => 'knowledges', :action => 'medias', :selector => :question

  # GET /aggregations/:knowledge_idurl/:product_idurl/[:feature_idurl]
  map.connect '/aggregations/:knowledge_idurl/:product_idurl/:feature_idurl', :controller => 'knowledges', :action => 'aggregations'
  map.connect '/aggregations/:knowledge_idurl/:product_idurl', :controller => 'knowledges', :action => 'aggregations'

  map.resources :products

  map.resources :users, :member => { :process_opinion => :get }
  map.connect '/profile/:user_idurl', :controller => 'users', :action => 'show_by_idurl'  
  map.connect '/answer', :controller => 'users', :action => 'record_answer'

  map.resources :knowledges
  map.connect '/distance/:knowledge_idurl/:feature_idurl', :controller => 'knowledges', :action => 'distance'
  map.connect '/distance/:knowledge_idurl', :controller => 'knowledges', :action => 'distance'
  map.connect '/matrix/:knowledge_idurl', :controller => 'knowledges', :action => 'matrix'

  map.connect '/edit/:knowledge_idurl', :controller => 'knowledges', :action => 'edit_by_idurl'

  map.connect '/questions/:knowledge_idurl/:question_idurl', :controller => 'knowledges', :action => 'show_question'
  map.connect '/questions/:knowledge_idurl', :controller => 'knowledges', :action => 'show_questions'

  map.connect '/test_results', :controller => 'home', :action => 'test_results'
  map.connect '/test_products_search', :controller => 'home', :action => 'test_products_search'
  map.connect '/test_quizz', :controller => 'home', :action => 'test_quizz'
  map.connect '/test_product_alone', :controller => 'home', :action => 'test_product_alone'
  map.connect '/test_product_results', :controller => 'home', :action => 'test_product_results'
  map.connect '/test_box', :controller => 'home', :action => 'test_box'
  map.connect '/test_product_page_results', :controller => 'home', :action => 'test_product_page_results'

  

  map.connect '/quiz/:knowledge_idurl/:quiz_idurl', :controller => 'knowledges', :action => 'quiz'
  map.connect '/quiz/:knowledge_idurl', :controller => 'knowledges', :action => 'quiz'


  map.connect '/access_restricted' , :controller => 'users', :action => 'access_restricted'
  map.connect '/login' , :controller => 'users', :action => 'login'
  map.connect '/logout' , :controller => 'users', :action => 'logout'

  map.connect "/rpx_token_sessions_url", :controller => 'users', :action => 'rpx_token_sessions_url'

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  map.root :controller => "home"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
