class Comment < ActiveRecord::Base
  belongs_to :commentable, polymorphic: true
  belongs_to :commenter, class_name: "User"
    validates :content, presence: true, allow_blank: false
end
