class Image < ActiveRecord::Base
  include Sociographer::Actionable
  include Sociable
  mount_uploader :image, ImageUploader
    validates :image, presence: true
  has_many :tags
    has_many :tagged_users, through: :tags, source: :user, class_name: "User"
end
