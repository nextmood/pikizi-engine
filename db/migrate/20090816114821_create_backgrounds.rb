class CreateBackgrounds < ActiveRecord::Migration
  def self.up
    create_table :backgrounds do |t|
      t.string :type
      t.string :knowledge_key
      t.string :feature_key
      t.string :product_key
      t.string :background_key
      t.string :label
      t.text :data
      t.integer :author_id
      t.string :author_key
      t.timestamps
    end
  end

  def self.down
    drop_table :backgrounds
  end
end
