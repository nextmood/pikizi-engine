class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.string :key
      t.string :label
      t.integer :author_id
      t.integer :nb_models,  :default => 0
      t.float :value_completion,  :default => 0.0
      t.timestamps
    end
  end

  def self.down
    drop_table :products
  end
end
