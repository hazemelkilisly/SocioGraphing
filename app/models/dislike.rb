class Dislike < ActiveRecord::Base
  belongs_to :dislikeable, polymorphic: true
  belongs_to :disliker, class_name: "User"
    validates_uniqueness_of :dislikeable_id, scope: [:disliker, :dislikeable_type]
end
