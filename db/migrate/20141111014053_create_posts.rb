class CreatePosts < ActiveRecord::Migration
  def change
    create_table :posts do |t|
      t.text :content
      t.belongs_to :user
      t.timestamps
    end
  end
end