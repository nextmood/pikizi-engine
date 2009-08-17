class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :key
      t.string :label
      t.integer :nb_quiz_instances, :default => 0
      t.integer :nb_authored_opinions,  :default => 0
      t.integer :nb_authored_values, :default => 0
      t.integer :nb_authored_backgrounds, :default => 0
      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end

