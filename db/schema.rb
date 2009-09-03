# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20090816114821) do

  create_table "backgrounds", :force => true do |t|
    t.string   "type"
    t.string   "knowledge_key"
    t.string   "feature_key"
    t.string   "product_key"
    t.string   "background_key"
    t.string   "label"
    t.text     "data"
    t.integer  "author_id"
    t.string   "author_key"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "knowledges", :force => true do |t|
    t.string   "key"
    t.string   "label"
    t.string   "author_key"
    t.integer  "nb_features",  :default => 0
    t.integer  "nb_products",  :default => 0
    t.integer  "nb_questions", :default => 0
    t.integer  "nb_quizzes",   :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "products", :force => true do |t|
    t.string   "key"
    t.string   "label"
    t.integer  "author_id"
    t.integer  "nb_models",        :default => 0
    t.float    "value_completion", :default => 0.0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "key"
    t.string   "rpx_identifier"
    t.string   "rpx_name"
    t.string   "rpx_username"
    t.string   "rpx_email"
    t.string   "promotion_code"
    t.string   "status",                  :default => "waiting_4_admin_authorization"
    t.integer  "nb_quiz_instances",       :default => 0
    t.integer  "nb_authored_opinions",    :default => 0
    t.integer  "nb_authored_values",      :default => 0
    t.integer  "nb_authored_backgrounds", :default => 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
