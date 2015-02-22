module Sociographer
  module Entity
    extend ActiveSupport::Concern
    included do

      after_create :create_person
      before_destroy :ensure_deletion_fixes

      @@neo = Neography::Rest.new

      # Call-Back after Creation of Entity (e.g. User)
        # to create the corresponding node in neo4j DB
      def create_person
        self_node = Neography::Node.create("object_id" => self.id, "object_type" => self.class.to_s)
        lists_node = Neography::Node.create("refrence_id" => self.id, "object_type" => "privacy_lists", "refrence_type" => self.class.to_s)
        lists_node["banned_list"] = Marshal.dump []
        lists_node["top_list"] = Marshal.dump []
      end

      # Get only the id of the corresponding node to the entity
      def get_node_id
        begin
          qur = "MATCH (n {object_id: #{self.id.to_s}, object_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
          response = @@neo.execute_query(qur)
          node_id = response["data"].flatten.first["metadata"]["id"]
          return node_id
        rescue Exception
          return nil
        end
      end

      # Get the corresponding node to the entity
      def get_node
        begin
          node_id = self.get_node_id
          node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
          return node
        rescue Exception
          return nil
        end
      end

      def get_lists_node_id
        begin
          qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
          response = @@neo.execute_query(qur)
          node_id = response["data"].flatten.first["metadata"]["id"]
          return node_id
        rescue Exception
          return nil
        end
      end

      def get_lists_node
        begin
          node_id = self.get_lists_node_id
          node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
          return node
        rescue Exception
          return nil
        end
      end

      # To Track the entity
      def track(entity)
        begin
          if entity.is_a?(Sociographer::Entity)
            # self_node = self.get_node
            # tracked_node = entity.get_node
            if !self.tracks?(entity) #&& self_node && tracked_node
              self.make_relation(entity, :friends)
              # relation = Neography::Relationship.create(:friends, self_node, tracked_node)
              # @@neo.set_relationship_properties(relation, {"magnitude" => 1, "created_at" => DateTime.now.to_i})
            else
              false
            end
          else
            false
          end
        rescue
          false
        end
      end

      # To unTrack the entity
      def untrack(entity)
        begin
          if entity.is_a?(Sociographer::Entity)
            self_node = self.get_node
            tracked_node = entity.get_node
            if self_node && tracked_node
              relation = @@neo.get_node_relationships_to(self_node, tracked_node, "out", :friends).first
              @@neo.delete_relationship(relation) if relation.present?
              return true
            else
              false
            end
          else
            false
          end
        rescue
          false
        end
      end

      # To get all trackers
      def trackers
        self_node = self.get_node
        if self_node
          trackers = []
          trackers_list = self_node.incoming(:friends).map{ |n| [n.object_type, n[:object_id]] }
          trackers_list = trackers_list.group_by{|x| x[0]}
          trackers_list.each do |tracker_type|
            tracker_ids = tracker_type[1].map{|u|u[1]}
            begin
              trackers << tracker_type[0].safe_constantize.where(id: tracker_ids).try(:to_a)
            rescue
            end
          end
          return trackers.flatten.compact.uniq
        else
          return []
        end
      end

      # To get all tracking entities
      def tracking
        self_node = self.get_node
        if self_node
          trackers = []
          trackers_list = self_node.outgoing(:friends).map{ |n| [n.object_type, n[:object_id]] }
          trackers_list = trackers_list.group_by{|x| x[0]}
          trackers_list.each do |tracker_type|
            tracker_ids = tracker_type[1].map{|u|u[1]}
            begin
              trackers << tracker_type[0].safe_constantize.where(id: tracker_ids).try(:to_a)
            rescue
            end
          end
          return trackers.flatten.compact.uniq
        else
          return []
        end
      end

      # To get friends: The common entities between trackers and trackings
      def friends
        friends = self.trackers & self.tracking
      end

      # To check if tracking the entity or not
      def tracks?(entity)
        if entity.is_a?(Sociographer::Entity)
          self_node_id = self.get_node_id
          tracked_node_id = entity.get_node_id
          if self_node_id && tracked_node_id
            qur = "start n1=node(#{self_node_id.to_s}), n2=node(#{tracked_node_id.to_s})  match n1-[r:friends]->n2 return r;"
            response = @@neo.execute_query(qur)
            unless response["data"].empty?
              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      # To check if friend with the entity or net
      def friend_with?(entity)
        if entity.is_a?(Sociographer::Entity)
          if self.tracks?(entity) && entity.tracks?(self)
            true
          else
            false
          end
        else
          false
        end
      end

      # Suggest friends: friends of friends
      def friend_suggestions
        self_node = self.get_node
        if self_node
          recommendations = self_node.outgoing(:friends).order("breadth first").uniqueness("node global").filter("position.length() == 2;").depth(2)
          all_recommendations = recommendations.map{|n| [n["object_type"], n["object_id"]] }
          grouped_by_type = all_recommendations.group_by{|x| x[0]}
          results = []
          grouped_by_type.each do |grouped_entities|
            entities_ids = grouped_entities[1].map{|u| u[1]}.compact.uniq
            result_entities = grouped_entities[0].safe_constantize.where(id: entities_ids).to_a
            results << result_entities
          end
          results.flatten!
          return results
        else
          false
        end
      end

      # Get all paths of entities between you and the entity (like linkedin)
      def all_degrees_of_separation(entity)
        if entity.is_a?(Sociographer::Entity)
          self_node = self.get_node
          entity_node = entity.get_node
          if self_node && entity_node
            paths = []
            found_entities = []
            self_node.all_simple_paths_to(entity_node).incoming(:friends).depth(5).nodes.each do |path|
              in_between = []
              path.each do |n|
                begin
                  ent = found_entities.select{|e| (e[:object_id] == n[:object_id]) && (e[:object_type] == n.object_type) }.first
                  if ent
                    ent = ent[:entity_record]
                  else
                    ent = n.object_type.safe_constantize.find_by(id: n[:object_id])
                    if ent
                      found_entities << {object_id: n[:object_id], object_type: n.object_type, entity_record: ent}
                    end
                  end
                  in_between << ent
                rescue
                end
              end
              unless in_between.include?(nil)
                paths << {length: in_between.size-1, users: in_between}
              end
            end
            return paths
          else
            false
          end
        else
          false
        end
      end

      # Get the shortest path of entities between you and the entity (like linkedin)
      def shortest_degrees_of_separation(entity)
        @@neo = Neography::Rest.new
        self_node = self.get_node
        entity_node = entity.get_node
        if self_node && entity_node
          paths = []
          self_node.shortest_path_to(entity_node).incoming(:friends).depth(5).nodes.each do |path|
            in_between = path.map{|n| begin n.object_type.safe_constantize.find(n[:object_id]) rescue nil end }
            unless in_between.include?(nil)
              path = {length: path.size-1, users: in_between}
              paths << path
            end
          end
          paths
        end
      end


      # To calculate a number representing the relation between you and the entity:
        # according to the weight of the relations, their magnitude, and their frequencies
        # according to each user
      def calculate_relation(entity, self_relations_weights=nil, self_relation_weight=nil)
        if entity.is_a?(Sociographer::Entity) && (self!=entity)
          self_node_id = self.get_node_id
          entity_node_id = entity.get_node_id
          if self_node_id && entity_node_id
            unless self_relations_weights
              self_relations_weights = self.all_relations_weights
            end
            entity_relations_weights = entity.all_relations_weights
            qur = "START source=node(#{self_node_id}), destination=node(#{entity_node_id}) MATCH p = source<-[*2..2]->destination RETURN RELATIONSHIPS(p);"
            relations = @@neo.execute_query(qur)["data"]
            weights = []
            relations.each do |relation|
              relation = relation.flatten

              source_relation = relation.first
              p source_relation
              source_relation_type = source_relation["type"]
              source_relation_magnitude = source_relation["data"]["magnitude"]
              self_rel_weight = self_relations_weights.select{|u| u[:relation] == source_relation_type}.first[:weight]
              source_relation_weight = self_rel_weight*source_relation_magnitude
              # p "source_relation_weight (#{source_relation["self"].split("/").last} of type #{source_relation_type}) = #{source_relation_weight}"

              destination_relation = relation.last
              p destination_relation
              destination_relation_type = destination_relation["type"]
              destination_relation_magnitude = destination_relation["data"]["magnitude"]
              entity_rel_weight = entity_relations_weights.select{|u| u[:relation] == destination_relation_type}.first[:weight]
              destination_relation_weight = entity_rel_weight*destination_relation_magnitude
              # p "destination_relation_weight (#{destination_relation["self"].split("/").last} of type #{destination_relation_type}) = #{destination_relation_weight}"

              both_weights = source_relation_weight*destination_relation_weight
              weights << both_weights
            end
            all_weights = weights.sum
            all_weights
          else
            0
          end
        else
          0
        end
      end

    
      # To sort the trackers according to "calculate_relation" method desendingly 
      def sorted_trackers
        ratings = []
        self_relations_weights = self.all_relations_weights
        self.trackers.each do |entity|
          ratings << {entity: entity, weight: self.calculate_relation(entity, self_relations_weights)}
        end
        return ratings.sort_by{ |h| h[:weight] }.reverse
      end

      # To sort the tracking entities according to "calculate_relation" method desendingly 
      def sorted_tracking
        ratings = []
        self_relations_weights = self.all_relations_weights
        self.tracking.each do |entity|
          ratings << {entity: entity, weight: self.calculate_relation(entity, self_relations_weights)}
        end
        return ratings.sort_by{ |h| h[:weight] }.reverse
      end

      # To sort the friends according to "calculate_relation" method desendingly 
      def sorted_friends
        ratings = []
        self_relations_weights = self.all_relations_weights
        self.friends.each do |entity|
          ratings << {entity: entity, weight: self.calculate_relation(entity, self_relations_weights)}
        end
        return ratings.sort_by{ |h| h[:weight] }.reverse
      end
  
      # Call it to make the relation between the entity and the actionable
      def make_relation(actionable, relation, magnitude=1)
        if (actionable.is_a?(Sociographer::Actionable) || actionable.is_a?(Sociographer::Entity)) && relation
          self_node = self.get_node
          actionable_node = actionable.get_node
          if self_node && actionable_node

            if magnitude
              magnitude = magnitude.try(:to_f).try(:round)
              if magnitude < 0
                magnitude = -1
              else
                magnitude = 1
              end
            else
              magnitude = 1
            end

            node_property = relation.to_s.parameterize.underscore.to_s
            self_node_property = self_node[node_property]
            if self_node_property
              self_node[node_property] = self_node_property+1
            elsif
              self_node[node_property] = 1
            end
            if actionable.is_a?(Sociographer::Actionable)
              actionable_node_property = actionable_node[node_property]
              if actionable_node_property
                actionable_node[node_property] = actionable_node_property+1
              elsif
                actionable_node[node_property] = 1
              end
            end

            relation = relation.to_s.parameterize.underscore.to_sym
            relation_relationship = Neography::Relationship.create(relation, self_node, actionable_node)
            @@neo.set_relationship_properties(relation_relationship, {"magnitude" => magnitude, "created_at" => DateTime.now.to_i})
            return true
          else
            false
          end
        else
          false
        end
      end

      # User's distinct relations with count
      def distinct_relations(from_cache=true)
        begin
          result_found = false
          if from_cache
            self_node = self.get_node
            distinct_relations = @@neo.get_node_properties(self_node)
            distinct_relations.except!("object_type", "object_id")
            distinct_relations = distinct_relations.map{|p|p}
            unless distinct_relations.empty?
              result_found = true
            end
          end
          unless result_found
            self_node_id = self.get_node_id
            qur = "start n=node("+self_node_id.to_s+") match n-[r]->() return distinct(type(r)), count(r);"
            response = @@neo.execute_query(qur)
            distinct_relations = response["data"]
          end
          return distinct_relations
        rescue Exception
          return nil
        end
      end

      def all_relations_sorted
        begin
          self_node_id = self.get_node_id
          qur = "start n=node("+self_node_id.to_s+") match n-[r]->() return type(r) ORDER BY r.created_at DESC;"
          response = @@neo.execute_query(qur)
          all_relations = response["data"]
          return all_relations
        rescue Exception
          return nil
        end
      end

      def all_relations_weights(complemented=true, from_cache=false)
        begin
          result_found = false
          if from_cache
            self_node = self.get_node
            distinct_relations = @@neo.get_node_properties(self_node)
            distinct_relations.except!("object_type", "object_id")
            distinct_relations = distinct_relations.map{|p|p}
            unless distinct_relations.empty?
              result_found = true
            end
          end
          unless result_found
            self_node_id = self.get_node_id
            qur = "start n=node("+self_node_id.to_s+") match n-[r]->() return distinct(type(r)), count(r);"
            response = @@neo.execute_query(qur)
            distinct_relations = response["data"]
          end
          if distinct_relations
            total_weight = distinct_relations.inject(0) {|sum,y| sum+y[1]}.to_f
            if total_weight
              if complemented
                all_relatios_w = distinct_relations.map{|u| {relation: u[0], weight: (1-(u[1].to_f/total_weight)) } }
              else
                all_relatios_w = distinct_relations.map{|u| {relation: u[0], weight: (u[1].to_f/total_weight) } }
              end
              return all_relatios_w
            else
              return[]
            end
          else
            return distinct_relations
          end
        rescue Exception
          return nil
        end
      end

      # User's specific relation with count // DONE
      def relation_count(relation, from_cache=true)
        begin
          relation = relation.to_s.parameterize.underscore.to_s
          relation_found = false
          if from_cache
            self_node = self.get_node
            relation_count = self_node[relation]
            if relation_count
              relation_found = true
            end
          end
          unless relation_found
            self_node_id = self.get_node_id
            qur = "start n=node(#{self_node_id.to_s}) match n-[r:#{relation}]->() return count(r);"
            response = @@neo.execute_query(qur)
            relation_count = response["data"].try(:flatten).try(:first)
          end
          return relation_count
        rescue Exception
          return nil
        end
      end

      # Calculates % of each relation from total relations count
      def relation_weight(relation, from_cache=true)
        begin
          relation = relation.to_s.parameterize.underscore.to_s
          if from_cache
            total_relations = self.distinct_relations(from_cache)
            total_relations_weights = total_relations.map{|u| u.try(:second)}.compact.flatten.sum
            relation_hash = total_relations.select{|u| u.try(:first)==relation}.first
            relation_hash ? rel_count=relation_hash[1] : rel_count=0
          else
            self_node_id = self.get_node_id
            qur = "start n=node(#{self_node_id.to_s}) match n-[r:#{relation}]->() return count(r);"
            response = @@neo.execute_query(qur)
            rel_count = response["data"].try(:flatten).try(:first)
            
            qur = "start n=node(#{self_node_id.to_s}) match n-[r]->() return count(r);"
            response = @@neo.execute_query(qur)
            total_relations_weights = response["data"].try(:flatten).try(:first)
          end
          if rel_count && !rel_count.try(:zero?) && total_relations_weights
            rel_count = rel_count.to_f
            total_relations_weights = total_relations_weights.to_f
            return 1-(rel_count/total_relations_weights)
          else
            return 0
          end
        rescue Exception
          return 0
        end
      end
      def profile_feed(page=1, per_page=30)
        if per_page < 1
          per_page = 20
        end
        skipped_no = (page-1)*per_page
        if skipped_no < 0
          skipped_no = 0
        end

        self_node_id = self.get_node_id
        qur = "start n=node("+self_node_id.to_s+") match n-[r]->(z) return type(r), z, r.created_at ORDER BY r.created_at DESC SKIP #{skipped_no.to_s} LIMIT #{per_page}"
        response = @@neo.execute_query(qur)
        feeds = []
        self_id = self.id
        self_type = self.class.name
        response["data"].each do |result|
          activity_type = result[0]
          attachment_data = result[1]["data"]
          activity_timestamp = Time.at(result[2]).to_datetime
          if activity_type && attachment_data && activity_timestamp
            feeds << FeedItem.new(activity_type, attachment_data["object_id"], attachment_data["object_type"], self_id, self_type, activity_timestamp, self)
          end
        end
        f_by_attachment = feeds.group_by{|x| x.attachment_type}
        f_by_attachment.each do |fbt|
          attachments_ids = fbt[1].map{|u| u.attachment_id}.compact.uniq
          attachments = fbt[0].safe_constantize.where(id: attachments_ids).to_a
          fbt[1].each do |feed_item|
            fi_attachment = attachments.select{ |a| a.id == feed_item.attachment_id}.first
            if fi_attachment
              feed_item.update_attachment(fi_attachment)
            else
              feed_item = nil
            end
          end
        end
        feeds = f_by_attachment.map{|u| u[1]}.flatten.compact
        feeds.sort_by{ |f| f.timestamp }
        feeds
      end

      def feed(page=1, per_page=30)
        if per_page < 1
          per_page = 20
        end
        skipped_no = (page-1)*per_page
        if skipped_no < 0
          skipped_no = 0
        end

        self_node_id = self.get_node_id
        qur = "start x=node("+self_node_id.to_s+") match x-[r:friends]->(y)-[r2]->(z) return type(r2), y, z, r2.created_at ORDER BY r2.created_at DESC SKIP #{skipped_no.to_s} LIMIT #{per_page}"
        response = @@neo.execute_query(qur)        
        feeds = []
        response["data"].each do |result|
          activity_type = result[0]
          actor_data = result[1]["data"]
          # actor = actor_data["object_type"].safe_constantize.find_by(id: actor_data["object_id"])
          attachment_data = result[2]["data"]
          # attachment = attachment_data["object_type"].safe_constantize.find_by(id: attachment_data["object_id"])
          activity_timestamp = Time.at(result[3]).to_datetime
          if activity_type && actor_data && attachment_data && activity_timestamp
            feeds << FeedItem.new(activity_type, attachment_data["object_id"], attachment_data["object_type"], actor_data["object_id"], actor_data["object_type"], activity_timestamp)
          end
        end
        f_by_attachment = feeds.group_by{|x| x.attachment_type}
        f_by_attachment.each do |fbt|
          attachments_ids = fbt[1].map{|u| u.attachment_id}.compact.uniq
          attachments = fbt[0].safe_constantize.where(id: attachments_ids).to_a
          fbt[1].each do |feed_item|
            fi_attachment = attachments.select{ |a| a.id == feed_item.attachment_id}.first
            if fi_attachment
              feed_item.update_attachment(fi_attachment)
            else
              feed_item = nil
            end
          end
        end
        f_by_actor = f_by_attachment.map{|u| u[1]}.flatten.compact
        f_by_actor = f_by_actor.group_by{|x| x.actor_type}
        f_by_actor.each do |fbt|
          actors_ids = fbt[1].map{|u| u.actor_id}.compact.uniq
          actors = fbt[0].safe_constantize.where(id: actors_ids).to_a
          fbt[1].each do |feed_item|
            fi_actor = actors.select{ |a| a.id == feed_item.actor_id}.first
            if fi_actor
              feed_item.update_actor(fi_actor)
            else
              feed_item = nil
            end
          end
        end
        feeds = f_by_actor.map{|u| u[1]}.flatten.compact
        feeds.sort_by{ |f| f.timestamp }
        feeds
      end

      def ban(entity)
        if entity.is_a?(Sociographer::Entity)
          entity_node_id = entity.get_node_id
          if entity_node_id
            qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
            response = @@neo.execute_query(qur)
            node_id = response["data"].flatten.first["metadata"]["id"]
            lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
            
            if lists_node

              banned_list = Marshal.load lists_node["banned_list"]
              banned_list << entity_node_id
              banned_list.uniq!
              lists_node["banned_list"] = Marshal.dump banned_list
              top_list = Marshal.load lists_node["top_list"]
              top_list.delete(entity_node_id)
              top_list.uniq!
              lists_node["top_list"] = Marshal.dump top_list

              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def unban(entity)
        if entity.is_a?(Sociographer::Entity)
          entity_node_id = entity.get_node_id
          if entity_node_id
            qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
            response = @@neo.execute_query(qur)
            node_id = response["data"].flatten.first["metadata"]["id"]
            lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
            
            if lists_node
              banned_list = Marshal.load lists_node["banned_list"]
              banned_list.delete(entity_node_id)
              lists_node["banned_list"] = Marshal.dump banned_list
              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def get_banned
        qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
        response = @@neo.execute_query(qur)
        node_id = response["data"].flatten.first["metadata"]["id"]
        lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
        if lists_node
          listed_entities = lists_node["banned_list"]
          listed_entities = Marshal.load listed_entities
          return listed_entities
        else
          false
        end
      end

      def add_top_friend(entity)
        if entity.is_a?(Sociographer::Entity)
          entity_node_id = entity.get_node_id
          if entity_node_id
            qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
            response = @@neo.execute_query(qur)
            node_id = response["data"].flatten.first["metadata"]["id"]
            lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
            
            if lists_node
              top_list = Marshal.load lists_node["top_list"]
              top_list << entity_node_id
              top_list.uniq!
              lists_node["top_list"] = Marshal.dump top_list
              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def remove_from_top_friends(entity)
        if entity.is_a?(Sociographer::Entity)
          entity_node_id = entity.get_node_id
          if entity_node_id
            qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
            response = @@neo.execute_query(qur)
            node_id = response["data"].flatten.first["metadata"]["id"]
            lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
            
            if lists_node
              top_list = Marshal.load lists_node["top_list"]
              top_list.delete(entity_node_id)
              lists_node["top_list"] = Marshal.dump top_list
              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def get_top_friends
        qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
        response = @@neo.execute_query(qur)
        node_id = response["data"].flatten.first["metadata"]["id"]
        lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
        if lists_node
          listed_entities = lists_node["top_list"]
          listed_entities = Marshal.load listed_entities
          return listed_entities
        else
          false
        end
      end

      def create_list(list_name)
        if list_name.class.name == "String" && !list_name.strip.empty?
          list_name = list_name.parameterize.underscore.to_s

          qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
          response = @@neo.execute_query(qur)
          node_id = response["data"].flatten.first["metadata"]["id"]
          lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
          
          if lists_node
            unless lists_node[list_name]
              lists_node[list_name] = Marshal.dump []
              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def add_to_list(list_name, entity)
        if list_name.class.name == "String" && !list_name.strip.empty?
          list_name = list_name.parameterize.underscore.to_s
          if entity.is_a?(Sociographer::Entity)
            entity_node_id = entity.get_node_id
            if entity_node_id
              qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
              response = @@neo.execute_query(qur)
              node_id = response["data"].flatten.first["metadata"]["id"]
              lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
              
              if lists_node
                desired_list = Marshal.load lists_node[list_name]
                unless desired_list
                  desired_list = []
                end
                desired_list << entity_node_id
                lists_node[list_name] = Marshal.dump desired_list
                true
              else
                false
              end
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def remove_from_list(list_name, entity)
        if list_name.class.name == "String" && !list_name.strip.empty?
          list_name = list_name.parameterize.underscore.to_s
          if entity.is_a?(Sociographer::Entity)
            entity_node_id = entity.get_node_id
            if entity_node_id
              qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
              response = @@neo.execute_query(qur)
              node_id = response["data"].flatten.first["metadata"]["id"]
              lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
              
              if lists_node
                desired_list = Marshal.load lists_node[list_name]
                if desired_list
                  desired_list.delete(entity_node_id)
                  lists_node[list_name] = Marshal.dump desired_list
                  true
                else
                  false
                end
              else
                false
              end
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      def get_from_list(list_name)
        if list_name.class.name == "String" && !list_name.strip.empty?
          list_name = list_name.parameterize.underscore.to_s
          qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
          response = @@neo.execute_query(qur)
          node_id = response["data"].flatten.first["metadata"]["id"]
          lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
          if lists_node
            listed_entities = lists_node[list_name]
            listed_entities = Marshal.load listed_entities
            return listed_entities
          else
            false
          end
        else
          false
        end
      end

      def get_all_privacy_lists
        qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
        response = @@neo.execute_query(qur)
        node_id = response["data"].flatten.first["metadata"]["id"]
        lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
        if lists_node
          lists = @@neo.get_node_properties(lists_node)
          lists.except!("object_type", "refrence_id", "refrence_type")
          return lists.map{|u|u[0]}
        else
          false
        end
      end

      def remove_privacy_list(list_name)
        if list_name.class.name == "String" && !list_name.strip.empty?
          list_name = list_name.parameterize.underscore.to_s
          qur = "MATCH (n {refrence_id: #{self.id.to_s}, object_type: \'privacy_lists\', refrence_type: \'#{self.class.name}\' }) RETURN n LIMIT 1"
          response = @@neo.execute_query(qur)
          node_id = response["data"].flatten.first["metadata"]["id"]
          lists_node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
          if lists_node
            @@neo.remove_node_properties(lists_node, list_name) 
          else
            false
          end
        else
          false
        end
      end

      def classify(entity)

      end

      # To Ensure updating the cached relation index in all tracking entities' nodes
      def ensure_deletion_fixes  
      end


#### Distribution Methods

      # def trackers_privacy_list(max_needed_lists_count = 5)
      #   original_list = self.sorted_trackers
      #   original_weights_list = original_list.map{|u| u[:weight] }
      #   divided_array = sort_array(original_weights_list)
      #   returned_list = dist_arr(original_list, divided_array)
      #   needed_loops = returned_list.size - max_needed_lists_count
      #   if needed_loops > 0
      #     returned_list = recombine_array(returned_list, needed_loops)
      #   end
      #   return returned_list
      # end
      # def tracking_privacy_list(max_needed_lists_count = 5)
      #   original_list = self.sorted_tracking
      #   original_weights_list = original_list.map{|u| u[:weight] }
      #   divided_array = sort_array(original_weights_list)
      #   returned_list = dist_arr(original_list, divided_array)
      #   needed_loops = returned_list.size - max_needed_lists_count
      #   if needed_loops > 0
      #     returned_list = recombine_array(returned_list, needed_loops)
      #   end
      #   return returned_list
      # end
      # def friends_privacy_list(max_needed_lists_count = 5)
      #   original_list = self.sorted_friends
      #   original_weights_list = original_list.map{|u| u[:weight] }
      #   divided_array = sort_array(original_weights_list)
      #   returned_list = dist_arr(original_list, divided_array)
      #   needed_loops = returned_list.size - max_needed_lists_count
      #   if needed_loops > 0
      #     returned_list = recombine_array(returned_list, needed_loops)
      #   end
      #   return returned_list
      # end

      # def recombine_array(returned_list, needed_loops)
      #   for i in 0..(needed_loops-1)
      #     listed_diff = returned_list.each_with_index.map{|u,i| u[0][:weight]-returned_list[i-1][-1][:weight]}.drop(1)
      #     min_index = listed_diff.index(listed_diff.min)
      #     changed_item = returned_list[min_index].zip(returned_list[min_index+1]).flatten.compact
      #     returned_list = returned_list - [returned_list[min_index]] - [returned_list[min_index+1]]
      #     returned_list.insert(min_index, changed_item)
      #   end
      #   return returned_list
      # end

      # def sort_array(original_array)
      #   original_array.sort!
      #   division_arr = []
      #   original_array.each_with_index do |value,index|
      #     if index == 0
      #       division_arr << 1
      #     elsif index == original_array.size-1
      #       division_arr << -1
      #     else
      #       prev_div = (value - original_array[index-1]).abs
      #       next_div = (value - original_array[index+1]).abs
      #       if prev_div < next_div
      #         division_arr << -1
      #       else
      #         division_arr << 1
      #       end
      #     end
      #   end
      #   divided_array = fix_arr(division_arr)
      #   return divided_array
      #   # dist_array = dist_arr(original_array, divided_array)
      # end


      # def fix_arr(div_arr)
      #   returned_arr = ""
      #   div_arr.each_with_index do |val, index|
      #     if (val == -1) && (div_arr[index+1] == 1)
      #       returned_arr << "10"
      #     else
      #       returned_arr << "1"
      #     end
      #   end
      #   returned_arr = returned_arr.split("0").map{|u| u.split("")}
      #   return returned_arr
      # end

      # def dist_arr(original_array, fixed_array)
      #   returned_arr = []
      #   fixed_array.each do |arr|
      #     taken_elements = original_array.take(arr.size)
      #     original_array = original_array.drop(arr.size)
      #     returned_arr << taken_elements
      #   end
      #   return returned_arr
      # end

    end
  end
end