class CreateLikes < ActiveRecord::Migration
  def change
    create_table :likes do |t|
      t.belongs_to :likeable, polymorphic: true
      t.belongs_to :liker, class_name: "User"
      t.timestamps
    end
  end
end
