class AddFieldsToChoice < ActiveRecord::Migration
  def self.up
    add_column :backgrounds, :question_key, :string
    add_column :backgrounds, :choice_key, :string
  end

  def self.down
    remove_column :backgrounds, :question_key
    remove_column :backgrounds, :choice_key
  end
end
