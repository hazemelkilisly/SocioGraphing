class Image < ActiveRecord::Base
  include Sociographer::Actionable
  include Sociable
  mount_uploader :image, ImageUploader
    validates :image, presence: true
end
