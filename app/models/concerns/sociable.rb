module Sociable
  extend ActiveSupport::Concern
  included do
    has_many :likes, as: :likeable, dependent: :destroy
      has_many :likers, through: :likes, source: :liker

    has_many :dislikes, as: :dislikeable, dependent: :destroy
      has_many :dislikers, through: :likes, source: :liker

    has_many :comments, as: :commentable, dependent: :destroy
      has_many :commenters, through: :comments, source: :commenter

    belongs_to :user
  end
end