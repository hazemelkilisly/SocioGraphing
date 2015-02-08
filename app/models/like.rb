class Like < ActiveRecord::Base
  belongs_to :likeable, polymorphic: true
  belongs_to :liker, class_name: "User"
    validates_uniqueness_of :likeable_id, scope: [:liker, :likeable_type]
end
