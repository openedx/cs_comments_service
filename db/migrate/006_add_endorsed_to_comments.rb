class AddEndorsedToComments < ActiveRecord::Migration
  def self.up
    add_column :comments, :endorsed, :boolean, :default => false
  end
  
  def self.down
    remove_column :comments, :endorsed
  end
end
