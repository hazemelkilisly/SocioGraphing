class Post < ActiveRecord::Base
  include Sociographer::Actionable
  include Sociable
  validates :content, presence: true
  has_many :re_posts
end
