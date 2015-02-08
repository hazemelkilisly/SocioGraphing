class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :prepare_user, except: [:index]

  def index
    @users = User.all.to_a
  end

  def show
    @relations_analytics = @user.distinct_relations
    @total_relation_count = @relations_analytics.map{|u| u[1]}.sum
    if @user != current_user
      @degrees_of_separation = current_user.shortest_degrees_of_separation(@user)
    end
  end

  def trackers
    @users = @user.sort_trackers
  end

  def trackings
    @users = @user.sort_trackings
  end

  def friends
    @users = @user.sort_friends
  end

  def posts
    @posts = (@user.posts+@user.re_posts).sort_by{ |post| post.created_at }.reverse
  end

  def images
    @images = @user.images
  end

  def friend_suggestions
    @users = current_user.friend_suggestions
  end

  def follow
    current_user.track(@user)
    redirect_to @user
  end

  def unfollow
    current_user.untrack(@user)
    redirect_to @user
  end

private
  def prepare_user
    @user = User.find_by(id: params[:id])
    unless @user
      redirect_to root_url, alert: "Something went wrong!"
    end
  end

end