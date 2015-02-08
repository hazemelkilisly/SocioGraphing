class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  include Sociographer::Entity
  
  validates :name, presence: true
  
  has_many :posts  
  has_many :re_posts

  has_many :images
  has_many :likes, foreign_key: :liker_id
    has_many :liked_posts, through: :likes, source: :likeable, source_type: "Post"
    has_many :liked_images, through: :likes, source: :likeable, source_type: "Image"
  has_many :dislikes, foreign_key: :disliker_id
    has_many :disliked_posts, through: :dislikes, source: :dislikeable, source_type: "Post"
    has_many :disliked_images, through: :dislikes, source: :dislikeable, source_type: "Image"
  has_many :comments, foreign_key: :commenter_id
    has_many :commented_on_posts, through: :comments, source: :commentable, source_type: "Post"
    has_many :commented_on_image, through: :comments, source: :commentable, source_type: "Image"
end
