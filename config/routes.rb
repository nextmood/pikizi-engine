ActionController::Routing::Routes.draw do |map|

  map.connect '/quizzes/:knowledge_idurl/:quizze_idurl/edit', :controller => 'quizzes', :action => 'edit'  
  map.connect '/quizzes/:knowledge_idurl/:quizze_idurl', :controller => 'quizzes', :action => 'show'
  map.connect '/quizzes/:knowledge_idurl', :controller => 'quizzes', :action => 'index'

  map.connect '/myquizze/:knowledge_idurl/:quizze_idurl', :controller => 'quizzes', :action => 'myquizze'
  map.connect '/myquizze/:knowledge_idurl', :controller => 'quizzes', :action => 'myquizze'
  map.connect '/myquizze_results', :controller => 'quizzes', :action => 'myquizze_results'

  map.resources :users, :member => { :process_review => :get }
  map.connect '/profile/:user_idurl', :controller => 'users', :action => 'show_by_idurl'  
  map.connect '/answer', :controller => 'users', :action => 'record_answer'
  map.connect '/end_quizze', :controller => 'users', :action => 'end_quizze'

  map.resources :knowledges
  map.connect '/distance/:knowledge_idurl/:feature_idurl', :controller => 'knowledges', :action => 'distance'
  map.connect '/distance/:knowledge_idurl', :controller => 'knowledges', :action => 'distance'
  map.connect '/show/:knowledge_idurl', :controller => 'knowledges', :action => 'show'

  map.connect '/questions/:knowledge_idurl/:question_idurl', :controller => 'questions', :action => 'show'
  map.connect '/questions/:knowledge_idurl', :controller => 'questions', :action => 'index'

  map.connect '/home' , :controller => 'home', :action => 'quizzes'
  map.connect '/test_results', :controller => 'home', :action => 'test_results'
  map.connect '/test_products_search', :controller => 'home', :action => 'test_products_search'
  map.connect '/test_quizz', :controller => 'home', :action => 'test_quizz'
  map.connect '/test_product_alone', :controller => 'home', :action => 'test_product_alone'
  map.connect '/test_product_results', :controller => 'home', :action => 'test_product_results'
  map.connect '/test_box', :controller => 'home', :action => 'test_box'
  map.connect '/test_product_page_results', :controller => 'home', :action => 'test_product_page_results' 

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
  map.connect "/beta_test/:user_idurl/:is_new_user", :controller => 'landing', :action => 'toggle_beta_test'
  map.connect "/thanks/:user_idurl/:is_new_user", :controller => 'landing', :action => 'thanks'

  # real pages...
  map.connect "/quizzes", :controller => 'home', :action => 'quizzes'
  map.connect "/start_quiz/:quizze_id", :controller => 'home', :action => 'start_quiz'
  map.connect "/my_quiz", :controller => 'home', :action => 'my_quiz'
  map.connect "/my_product/:product_idurl", :controller => 'home', :action => 'my_product'
  map.connect "/record_my_answer", :controller => 'home', :action => 'record_my_answer'
  map.connect "/my_results", :controller => 'home', :action => 'my_results'
  map.connect "/product/:product_idurl", :controller => 'home', :action => 'product'
  map.connect "/products_search", :controller => 'home', :action => 'products_search'

  map.root :controller => "landing"  # default

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
