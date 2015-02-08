class CreateRePosts < ActiveRecord::Migration
  def change
    create_table :re_posts do |t|
      t.belongs_to :post
      t.belongs_to :user
      t.timestamps
    end
  end
end
