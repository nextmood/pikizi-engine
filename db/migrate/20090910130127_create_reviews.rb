class CreateReviews < ActiveRecord::Migration
  def self.up
    create_table :reviews do |t|
      t.string :type
      t.string :knowledge_key
      t.string :feature_key
      t.string :product_key
      t.string :media_key
      t.string :author_key
      t.integer :author_id
      t.text :data
      t.timestamps
    end
  end

  def self.down
    drop_table :reviews
  end
end
