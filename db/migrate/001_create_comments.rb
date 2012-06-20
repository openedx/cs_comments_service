# Taken and modified from gem 'acts_as_commentable_with_threading': 
# https://github.com/elight/acts_as_commentable_with_threading/blob/master/lib/generators/acts_as_commentable_with_threading_migration/templates/migration.rb

class CreateComments < ActiveRecord::Migration
  def self.up
    create_table :comments do |t|
      t.text    :body
      t.text    :title, :default => ""
      t.string  :ancestry
      t.integer :user_id
      t.integer :course_id
      t.integer :comment_thread_id
      t.timestamps
    end
    
    add_index :comments, :user_id
    add_index :comments, :course_id
    add_index :comments, :ancestry
  end
  
  def self.down
    drop_table :comments
  end
end
