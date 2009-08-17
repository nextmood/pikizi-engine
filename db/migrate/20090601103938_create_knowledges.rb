class CreateKnowledges < ActiveRecord::Migration
  def self.up
    create_table :knowledges do |t|
      t.string :key
      t.string :label
      t.string :author_key
      
      t.integer :nb_features, :default => 0
      t.integer :nb_products, :default => 0
      t.integer :nb_questions, :default => 0
      t.integer :nb_quizzes, :default => 0
      
      t.timestamps
    end
  end

  def self.down
    drop_table :knowledges
  end
end
