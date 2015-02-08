class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.belongs_to :commentable, polymorphic: true
      t.belongs_to :commenter, class_name: "User"
      t.text :content
      t.timestamps
    end
  end
end
