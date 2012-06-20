class CreateVotes < ActiveRecord::Migration
  def self.up
    create_table :votes do |t|
      t.integer :user_id
      t.integer :comment_id
      t.string  :value
      t.timestamps
    end

    add_index :votes, :comment_id
    add_index :votes, :user_id
    add_index :votes, [:comment_id, :user_id]
  end

  def self.down
    drop_table :votes
  end
end
