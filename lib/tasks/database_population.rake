task :populate_database => :environment do

  # number of users
  no_of_users = 100
  # number of posts for each user
  no_of_posts = 50
  # number of images upload count for each user
  no_of_images = 0
  # social interactions number (% from total images -divided in random-) for posts/image by tracked users
  post_inter_count = 50
  image_inter_count = 50

  no_of_friends = 20

  # Initializing DB with Data
  p "AAAAA Initializing DB with Data AAAAA"
  benchmark_results = [] 
  password = "12345678"
  no_of_users.times do
    name = Faker::Name.name
    email = Faker::Internet.email(name.split(" ").join('_'))
    country = Faker::Address.country
    job = Faker::Name.title
    p "Added =>>"+name+", "+email+", "+country+", "+job
    benchmark_results << Benchmark.realtime { User.create(email: email, name: name, country: country, job: job, password: password) }*1000
  end
  benchmark_final_count = benchmark_results.size
  benchmark_final = benchmark_results.inject(0.0) { |sum, el| sum + el } / benchmark_final_count
  benchmark_final_first = benchmark_results.first( ((benchmark_final_count*0.2).to_i) ).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)
  benchmark_final_last = benchmark_results.last(((benchmark_final_count*0.2).to_i)).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)

  p "Creating users Benchmark average over #{benchmark_results.size}: #{benchmark_final} - with starting: #{benchmark_final_first}, and ending: #{benchmark_final_last}"

  p "AAAAA FINISHED CREATING DB DATA AAAAA"

  users_count = User.count
  all_users = User.all.to_a
  all_ids = all_users.map(&:id).compact

  # Follow distinct 3 people to start with
  p "BBBBB Follow distinct 15 people to start with BBBBB"
  benchmark_results = []
  all_users.each do |user|
    selected_ids = [user.id]
    no_of_friends.times do
      random_ids_list = (all_ids-selected_ids)
      random_id_except_selected = random_ids_list.sample
      selected_random_user = User.find(random_id_except_selected)
      benchmark_results << Benchmark.realtime { user.follow(selected_random_user) }*1000 
      selected_ids << random_id_except_selected
      p "Followed =>> User: #{user.name} => #{selected_random_user.name} "
    end
  end
  benchmark_final_count = benchmark_results.size
  benchmark_final = benchmark_results.inject(0.0) { |sum, el| sum + el } / benchmark_final_count
  benchmark_final_first = benchmark_results.first( ((benchmark_final_count*0.2).to_i) ).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)
  benchmark_final_last = benchmark_results.last(((benchmark_final_count*0.2).to_i)).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)
  p "Following users Benchmark average over #{benchmark_results.size}: #{benchmark_final} - with starting: #{benchmark_final_first}, and ending: #{benchmark_final_last}"

  # # Expand more to a certain limit: max= min( 500 , ((users_count*0.2).floor) )
  # p "Expand more to a certain limit: max= min( 500 , ((users_count*0.2).floor) )"
  # accepted_max_users = (users_count*0.2).round
  # all_users.each do |user|
  #   random_max = accepted_max_users

  #   # start with recommendations
  #   p "start with recommendations"
  #   recommended_users = user.friend_suggestions
  #   recommended_users.sample(random_max).each do |rec_user|
  #     user.follow(rec_user)
  #     p "Followed =>> User: #{user.name} => #{rec_user.name} "
  #   end

  #   # fill the rest of the random max randomly
  #   p "fill the rest of the random max randomly"
  #   user_trackings = user.followed
  #   selected_ids = user_trackings.map{|u| u.id}+[user.id]
  #   user_trackings_count = user_trackings.count
  #   if user_trackings_count < random_max
  #     random_max = random_max-user_trackings_count
  #     random_max.times do
  #       random_id_except_selected = (all_ids-selected_ids).sample
  #       selected_random_user = User.find(random_id_except_selected)
  #       user.follow(selected_random_user)
  #       selected_ids << random_id_except_selected
  #       p "Followed =>> User: #{user.name} => #{selected_random_user.name} "
  #     end
  #   end
  # end
  # accepted_max_users, all_accepted_maxs, random_max, user_trackings, selected_ids, user_trackings_count, random_id_except_selected = [nil]*7
  # p "BBBBB FINISHED FOLLOWING PEOPLE BBBBB"

  # Ensure friendship is min 40% and max 70% of trackings
    # user_trackers = user.trackers
    # user_trackings = user.trackings
    # user_trackers_ids = user_trackers.map(:id)
    # user_trackings_ids = user_trackings.map(:id)
    # user_friends_ids = user_trackers_ids&user_trackings_ids
    # user_friends_count = user_friends_ids.count

  # Create Posts for users: min= 5, max = 10
  benchmark_results = []
  p "CCCCC Create Posts for users: min= 5, max = 10 CCCCC"
  all_users.each do |user|
    no_of_posts.times do
      post_caption = Faker::Lorem.paragraph
      created_post = Post.new(user: user, content: post_caption)
      if created_post.save
        p "Posting activity Benchmark #{user.id}:"
        benchmark_results << Benchmark.realtime { user.make_activity(actionable: created_post, activity_type: :posted) }*1000
        
        p "Posted =>> User: #{user.name} => #{post_caption}"
      end
    end
  end
  p "CCCCC FINISHED CREATING POSTS CCCCC"
  benchmark_final_count = benchmark_results.size
  benchmark_final = benchmark_results.inject(0.0) { |sum, el| sum + el } / benchmark_final_count
  benchmark_final_first = benchmark_results.first( ((benchmark_final_count*0.2).to_i) ).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)
  benchmark_final_last = benchmark_results.last(((benchmark_final_count*0.2).to_i)).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)
  p "Create Posts Benchmark average over #{benchmark_results.size}: #{benchmark_final} - with starting: #{benchmark_final_first}, and ending: #{benchmark_final_last}"


  # Upload images for users: min=0, max = 3, For sizes issues on download
  # p "DDDDD Upload images for users: min=0, max = 3 DDDDD"
  # all_users.each do |user|
  #   no_of_images.times do
  #     image_url = Faker::Company.logo
  #     # user.images.create(remote_image_url: image_url)
  #     created_image = Image.new(remote_image_url: image_url, user: user)
  #     if created_image.save
  #       user.make_activity(actionable: created_image, activity_type: :uploaded_image)
  #       p "Uploaded Image =>> User: #{user.name} => #{image_url}"
  #     end
  #   end
  # end
  # p "CCCCC FINISHED UPLOADING IMAGES CCCCC"

  # Like/Dislike/Repost/Comment random posts (with %: min 30%, max 70%) for user
  # Like/Dislike/Comment random images (with %: min 30%, max 70%) for user
  p "DDDDD Adding Social Interactions DDDDD"
  negative_sides_actions = ["like", "dislike"]
  complementry_post_actions = ["repost", "comment"]
  complementry_image_actions = ["comment", "comment", "tagged_in"]

  benchmark_results = []
  all_users.each do |user|
    user_trackings = user.followed

    # Posts Calculations
    p "Posts Calculations"
    available_posts = user_trackings.map{ |u| u.posts.to_a}.flatten.uniq.compact #all posts for trackings
    # selected_count_of_posts = ((available_posts.count)*(inter_count.to_f/100)).to_i
    selected_posts = available_posts.sample(post_inter_count)
    selected_posts.each do |post|
      p "Post: #{post.id}"
      current_negative_sides_action = negative_sides_actions.sample
      current_complementry_post_action = complementry_post_actions.sample
      
      case current_negative_sides_action
      when "like"
        user.liked_posts << post
        user.save
        post.reload
        if post.present?
          benchmark_results << Benchmark.realtime { user.make_activity(actionable: post, activity_type: :liked) }*1000

          
          p "Liked Post =>> User: #{user.name}"
        end
      else "dislike"
        user.disliked_posts << post
        user.save
        benchmark_results << Benchmark.realtime { user.make_activity(actionable: post, activity_type: :disliked, magnitude: -1) }*1000
        
        p "DisLiked Post =>> User: #{user.name}"
      end

      case current_complementry_post_action
      when "repost"
        user.re_posts.create(post: post)

        benchmark_results << Benchmark.realtime { user.make_activity(actionable: post, activity_type: :re_posted) }*1000

        p "Reposted Post =>> User: #{user.name}"
      when "comment"
        comment_content = Faker::Lorem.sentence
        user.comments.create(commentable: post, content: comment_content)
        
        benchmark_results << Benchmark.realtime { user.make_activity(actionable: post, activity_type: :commented) }*1000

        p "Commented Post =>> User: #{user.name}"
      end

    end
    p "FINISHED POST INTERACTIONS"
    benchmark_final_count = benchmark_results.size
    benchmark_final = benchmark_results.inject(0.0) { |sum, el| sum + el } / benchmark_final_count
    benchmark_final_first = benchmark_results.first( ((benchmark_final_count*0.2).to_i) ).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)
    benchmark_final_last = benchmark_results.last(((benchmark_final_count*0.2).to_i)).inject(0.0) { |sum, el| sum + el } / ((benchmark_final_count*0.2).to_i)
    p "Post Activities Benchmark average over #{benchmark_results.size}: #{benchmark_final} - with starting: #{benchmark_final_first}, and ending: #{benchmark_final_last}"

    # # Images Calculations
    # p "Images Calculations"
    # available_images = user_trackings.map{ |u| u.images.to_a}.flatten #all posts for trackings
    # # selected_count_of_images = ((available_images.count)*(inter_count.to_f/100)).to_i
    # selected_images = available_images.sample(image_inter_count)
    # selected_images.each do |image|
    #   p "Image: #{image.id}"
    #   current_negative_sides_action = negative_sides_actions.sample
    #   current_complementry_image_action = complementry_image_actions.sample
      
    #   case current_negative_sides_action
    #   when "like"
    #     user.liked_images << image
    #     user.save
    #     user.make_activity(actionable: image, activity_type: :liked)
    #     p "Liked Image =>> User: #{user.name}"
    #   when "dislike"
    #     user.disliked_images << image
    #     user.save
    #     user.make_activity(actionable: image, activity_type: :disliked, magnitude: -1)
    #     p "DisLiked Image =>> User: #{user.name}"
    #   end
    #   current_negative_sides_action = nil

    #   case current_complementry_image_action
    #   when "comment"
    #     comment_content = Faker::Lorem.sentence
    #     user.comments.create(commentable: image, content: comment_content)
    #     user.make_activity(actionable: image, activity_type: :commented)
    #     p "Commented on Image =>> User: #{user.name}"
    #   when "tagged_in"
    #     Tag.create(user: user, image: image)
    #     user.make_activity(actionable: image, activity_type: :tagged_in)
    #     p "Tagged in Image =>> User: #{user.name}"
    #   end
    #   current_complementry_image_action = nil
    # end
    # p "FINISHED POST INTERACTIONS"

    user_trackings = nil
  end
  p "DDDDD FINISHED SOCIAL INTERACTIONS DDDDD"
end