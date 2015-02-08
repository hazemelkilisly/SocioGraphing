class CreateDislikes < ActiveRecord::Migration
  def change
    create_table :dislikes do |t|
      t.belongs_to :dislikeable, polymorphic: true
      t.belongs_to :disliker, class_name: "User"
      t.timestamps
    end
  end
end
