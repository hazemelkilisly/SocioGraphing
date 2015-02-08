class PostsController < ApplicationController
  before_action :authenticate_user!
  before_action :prepare_post_user
  before_action :require_action_ability, only: [:like, :dislike, :repost, :comment]
  before_action :require_ownership, only: [:destroy]

  def show
  end

  def like
    current_user.liked_posts << @post
    if current_user.save
      current_user.make_relation(@post, :liked)
    end
    redirect_to @post
  end

  def dislike
    current_user.disliked_posts << @post
    if current_user.save
      current_user.make_relation(@post, :disliked, -1)
    end
    redirect_to @post
  end

  def repost
    if current_user.re_posts.create(post: @post)
      current_user.make_relation(@post, :re_posted)
    end
    redirect_to current_user
  end

  def comment
    comment_content = params[:comment]
    if current_user.comments.create(commentable: @post, content: comment_content)
      current_user.make_relation(@post, :commented)
    end
    redirect_to @post
  end

  def destroy
    @post.destroy
    redirect_to current_user
  end

private
  def prepare_post_user
    @post = Post.find_by(id: params[:id])
    @user = @post.user
    unless @post
      redirect_to root_url, alert: "Something went wrong!"
    end
  end
  def require_action_ability
    unless current_user.trackers.include?(@post.user)
      redirect_to root_url, alert: "You should track this profile first!"
    end
  end
  def require_ownership
    unless @post.user == current_user
      redirect_to root_url, alert: "You are not the owner of the post!"
    end
  end
end
