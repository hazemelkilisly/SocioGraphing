class ImagesController < ApplicationController
  before_action :authenticate_user!
  before_action :prepare_image
  before_action :require_action_ability, only: [:like, :dislike, :comment]
  before_action :require_ownership, only: [:destroy]

  def show
  end

  def like
    current_user.liked_images << @image
    if current_user.save
      current_user.make_relation(@image, :liked)
    end
    redirect_to @image
  end

  def dislike
    current_user.disliked_images << @image
    if current_user.save
      current_user.make_relation(@image, :disliked, -1)
    end
    redirect_to @image
  end

  def comment
    comment_content = params[:comment]
    if current_user.comments.create(commentable: @image, content: comment_content)
      current_user.make_relation(@image, :commented)
    end
    redirect_to @image
  end

  def destroy
    @image.destroy
    redirect_to current_user
  end

private
  def prepare_image
    @image = Image.find_by(id: params[:id])
    @user = @image.user
    unless @image
      redirect_to root_url, alert: "Something went wrong!"
    end
  end
  def require_action_ability
    unless current_user.trackers.include?(@image.user)
      redirect_to root_url, alert: "You should track this profile first!"
    end
  end
  def require_ownership
    unless @image.user == current_user
      redirect_to root_url, alert: "You are not the owner of the image!"
    end
  end
end