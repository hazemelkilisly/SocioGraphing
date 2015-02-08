class CreateImages < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.string :image
      t.belongs_to :user
      t.timestamps
    end
  end
end
