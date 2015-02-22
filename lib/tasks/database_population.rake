task :populate_database => :environment do

  # needed number of users
  no_of_users = 50
  # min..max number of posts for each user
  random_posts_array = [*5..15]
  # random images upload count for each user
  random_images_array = [*0..5]
  # random social interactions number (% from total images -divided in random-) for posts/image by tracked users
  random_percentage = [*25..70]

  # Initializing DB with Data
  p "AAAAA Initializing DB with Data AAAAA"
  password = "12345678"
  no_of_users.times do
    name = Faker::Name.name
    email = Faker::Internet.email(name.split(" ").join('_'))
    country = Faker::Address.country
    job = Faker::Name.title
    p "Added =>>"+name+", "+email+", "+country+", "+job
    User.create(email: email, name: name, country: country, job: job, password: password)
    name, email, country, job = [nil]*4
  end
  p "AAAAA FINISHED CREATING DB DATA AAAAA"

  users_count = User.count
  all_ids = [*1..users_count]
  all_users = User.all.to_a


  # Follow distinct 3 people to start with
  p "BBBBB Follow distinct 3 people to start with BBBBB"
  all_users.each do |user|
    selected_ids = [user.id]
    3.times do
      random_ids_list = (all_ids-selected_ids)
      random_id_except_selected = random_ids_list.sample
      selected_random_user = User.find(random_id_except_selected)
      user.track(selected_random_user)
      selected_ids << random_id_except_selected
      p "Followed =>> User: #{user.name} => #{selected_random_user.name} "
      random_id_except_selected = nil
      random_ids_list = nil
      selected_random_user = nil
    end
    selected_ids = nil
  end

  # Expand more to a certain limit: max= min( 500 , ((users_count*0.2).floor) )
  p "Expand more to a certain limit: max= min( 500 , ((users_count*0.2).floor) )"
  accepted_max_users = [ 50, ((users_count*0.2).floor) ].min
  all_accepted_maxs = [*1..accepted_max_users]
  all_users.each do |user|
    random_max = all_accepted_maxs.sample

    # start with recommendations
    p "start with recommendations"
    recommended_users = user.friend_suggestions
    recommended_users.sample(random_max).each do |rec_user|
      user.track(rec_user)
      p "Followed =>> User: #{user.name} => #{rec_user.name} "
    end
    recommended_users = nil

    # fill the rest of the random max randomly
    p "fill the rest of the random max randomly"
    user_trackings = user.tracking
    selected_ids = user_trackings.map{|u| u.id}+[user.id]
    user_trackings_count = user_trackings.count
    if user_trackings_count < random_max
      random_max = random_max-user_trackings_count
      random_max.times do
        random_id_except_selected = (all_ids-selected_ids).sample
        selected_random_user = User.find(random_id_except_selected)
        user.track(selected_random_user)
        selected_ids << random_id_except_selected
        p "Followed =>> User: #{user.name} => #{selected_random_user.name} "
        selected_random_user = nil
      end
    end
  end
  accepted_max_users, all_accepted_maxs, random_max, user_trackings, selected_ids, user_trackings_count, random_id_except_selected = [nil]*7
  p "BBBBB FINISHED FOLLOWING PEOPLE BBBBB"

  # Ensure friendship is min 40% and max 70% of trackings
    # user_trackers = user.trackers
    # user_trackings = user.trackings
    # user_trackers_ids = user_trackers.map(:id)
    # user_trackings_ids = user_trackings.map(:id)
    # user_friends_ids = user_trackers_ids&user_trackings_ids
    # user_friends_count = user_friends_ids.count

  # Create Posts for users: min= 5, max = 10
  p "CCCCC Create Posts for users: min= 5, max = 10 CCCCC"
  all_users.each do |user|
    random_posts_count = random_posts_array.sample
    random_posts_count.times do
      post_caption = Faker::Lorem.paragraph
      created_post = Post.create(user: user, content: post_caption)
      user.make_relation(created_post, :posted)
      # user.posts.create(content: post_caption)
      p "Posted =>> User: #{user.name} => #{post_caption}"
      post_caption = nil
    end
  end
  random_posts_array = nil
  p "CCCCC FINISHED CREATING POSTS CCCCC"

  # Upload images for users: min=0, max = 3, For sizes issues on download
  p "DDDDD Upload images for users: min=0, max = 3 DDDDD"
  all_users.each do |user|
    random_images_count = random_images_array.sample
    random_images_count.times do
      image_url = Faker::Company.logo
      # user.images.create(remote_image_url: image_url)
      created_image = Image.create(remote_image_url: image_url, user: user)
      user.make_relation(created_image, :uploaded_image)
      p "Uploaded Image =>> User: #{user.name} => #{image_url}"
      image_url = nil
    end
  end
  random_images_array = nil
  p "CCCCC FINISHED UPLOADING IMAGES CCCCC"

  # Like/Dislike/Repost/Comment random posts (with %: min 30%, max 70%) for user
  # Like/Dislike/Comment random images (with %: min 30%, max 70%) for user
  p "DDDDD Adding Social Interactions DDDDD"
  negative_sides_actions = ["like", "dislike"]
  complementry_post_actions = ["repost", "comment", "none", "none"]
  complementry_image_actions = ["comment", "comment", "tagged_in", "none"]

  all_users.each do |user|
    user_trackings = user.tracking

    # Posts Calculations
    p "Posts Calculations"
    random_posts_percentage_count = random_percentage.sample
    available_posts = user_trackings.map{ |u| u.posts.to_a}.flatten #all posts for trackings
    selected_count_of_posts = ((available_posts.count)*(random_posts_percentage_count.to_f/100)).to_i
    selected_posts = available_posts.sample(selected_count_of_posts)
    selected_posts.each do |post|
      p "Post: #{post.id}"
      current_negative_sides_action = negative_sides_actions.sample
      current_complementry_post_action = complementry_post_actions.sample
      
      case current_negative_sides_action
      when "like"
        user.liked_posts << post
        user.save
        user.make_relation(post, :liked)
        p "Liked Post =>> User: #{user.name}"
      else "dislike"
        user.disliked_posts << post
        user.save
        user.make_relation(post, :disliked, -1)
        p "DisLiked Post =>> User: #{user.name}"
      end
      current_negative_sides_action = nil

      case current_complementry_post_action
      when "repost"
        user.re_posts.create(post: post)
        user.make_relation(post, :re_posted)
        p "Reposted Post =>> User: #{user.name}"
      when "comment"
        comment_content = Faker::Lorem.sentence
        user.comments.create(commentable: post, content: comment_content)
        user.make_relation(post, :commented)
        p "Commented Post =>> User: #{user.name}"
      else
        false
      end
      current_complementry_post_action = nil

    end
    random_posts_percentage_count, available_posts, selected_count_of_posts, selected_posts = [nil]*4
    p "FINISHED POST INTERACTIONS"

    # Images Calculations
    p "Images Calculations"
    random_images_percentage_count = random_percentage.sample
    available_images = user_trackings.map{ |u| u.images.to_a}.flatten #all posts for trackings
    selected_count_of_images = ((available_images.count)*(random_images_percentage_count.to_f/100)).to_i
    selected_images = available_images.sample(selected_count_of_images)
    selected_images.each do |image|
      p "Image: #{image.id}"
      current_negative_sides_action = negative_sides_actions.sample
      current_complementry_image_action = complementry_image_actions.sample
      
      case current_negative_sides_action
      when "like"
        user.liked_images << image
        user.save
        user.make_relation(image, :liked)
        p "Liked Image =>> User: #{user.name}"
      when "dislike"
        user.disliked_images << image
        user.save
        user.make_relation(image, :disliked, -1)
        p "DisLiked Image =>> User: #{user.name}"
      end
      current_negative_sides_action = nil

      case current_complementry_image_action
      when "comment"
        comment_content = Faker::Lorem.sentence
        user.comments.create(commentable: image, content: comment_content)
        user.make_relation(image, :commented)
        p "Commented on Image =>> User: #{user.name}"
      when "tagged_in"
        Tag.create(user: user, image: image)
        user.make_relation(image, :tagged_in)
        p "Tagged in Image =>> User: #{user.name}"
      else
        false
      end
      current_complementry_image_action = nil
    end
    random_images_percentage_count, available_images, selected_count_of_images, selected_images = [nil]*4
    p "FINISHED POST INTERACTIONS"

    user_trackings = nil
  end
  random_percentage, negative_sides_actions, complementry_post_actions, complementry_image_actions = [nil]*4
  p "DDDDD FINISHED SOCIAL INTERACTIONS DDDDD"

end