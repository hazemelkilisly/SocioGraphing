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
        Neography::Node.create("object_id" => self.id, "object_type" => self.class.to_s)
      end

      # Get only the id of the corresponding node to the entity
      def get_node_id
        # @@neo = Neography::Rest.new
        begin
          qur = "MATCH (n {object_id: "+self.id.to_s+", object_type: \'"+self.class.to_s+"\' }) RETURN n LIMIT 1"
          response = @@neo.execute_query(qur)
          node_id = response["data"].flatten.first["metadata"]["id"]
          return node_id
        rescue Exception
          return nil
        end
      end

      # Get the corresponding node to the entity
      def get_node
        # @@neo = Neography::Rest.new
        begin
          # qur = "MATCH (n {object_id: "+self.id.to_s+", object_type: \'"+self.class.to_s+"\' }) RETURN n LIMIT 1"
          # response = @@neo.execute_query(qur)
          # node_id = response["data"].flatten.first["metadata"]["id"]
          node_id = self.get_node_id
          node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
          return node
        rescue Exception
          return nil
        end
      end

      # To Ensure updating the cached relation index in all tracking entities' nodes
      def ensure_deletion_fixes  
        # TO DO
      end

      # To Track the entity
      def track(entity)
        if entity.is_a?(Sociographer::Entity)
          # @@neo = Neography::Rest.new
          self_node = self.get_node
          tracked_node = entity.get_node
          if self_node && tracked_node && !self.tracks?(entity)
            relation = Neography::Relationship.create(:friends, self_node, tracked_node)
            @@neo.set_relationship_properties(relation, {"magnitude" => 1, "created_at" => DateTime.now.to_i})
          else
            false
          end
        else
          false
        end
      end

      # To unTrack the entity
      def untrack(entity)
        if entity.is_a?(Sociographer::Entity)
          # @@neo = Neography::Rest.new
          self_node = self.get_node
          tracked_node = entity.get_node
          if self_node && tracked_node
            relation = @@neo.get_node_relationships_to(self_node, tracked_node, "out", :friends).first
            @@neo.delete_relationship(relation) if relation.present?
            return true
            # self_node.outgoing(:friends) << tracked_node
          else
            false
          end
        else
          false
        end
      end

      # To check if tracking the entity or not
      def tracks?(entity)
        if entity.is_a?(Sociographer::Entity)
          # @@neo = Neography::Rest.new
          self_node = self.get_node
          tracked_node = entity.get_node
          if self_node && tracked_node
            self_node.outgoing(:friends).map{|u| u}.include?(tracked_node)
          else
            false
          end
        else
          false
        end
      end

      # To get all trackers
      def trackers
        # @@neo = Neography::Rest.new
        self_node = User.first.get_node
        if self_node
          trackers = []
          begin
            trackers_list = self_node.incoming(:friends).map{ |n| [n.object_type, n[:object_id]] }
            trackers_list = trackers_list.group_by{|x| x[0]}
            trackers_list.each do |tracker_type|
              tracker_ids = tracker_type[1].map{|u|u[1]}
              trackers << tracker_type[0].safe_constantize.where(id: tracker_ids).try(:to_a)
            end
          rescue Exception
          end
          return trackers.flatten
        else
          return []
        end
      end

      # To get all tracking entities
      def tracking
        # @@neo = Neography::Rest.new
        self_node = self.get_node
        if self_node
          trackers = []
          begin
            trackers_list = self_node.outgoing(:friends).map{ |n| [n.object_type, n[:object_id]] }
            trackers_list = trackers_list.group_by{|x| x[0]}
            trackers_list.each do |tracker_type|
              tracker_ids = tracker_type[1].map{|u|u[1]}
              trackers << tracker_type[0].safe_constantize.where(id: tracker_ids).try(:to_a)
            end
          rescue Exception
          end

          return trackers.flatten
        else
          return []
        end
      end

      # To get friends: The common entities between trackers and trackings
      def friends
        # @@neo = Neography::Rest.new
        friends = self.trackers & self.tracking
      end

      # To check if friend with the entity or net
      def friend_with?(entity)
        if entity.is_a?(Sociographer::Entity)
          # @@neo = Neography::Rest.new
          # self_node = self.get_node
          tracked_node = entity.get_node
          # if self_node && tracked_entity_node
          #   trackings = self_node.outgoing(:friends).map{ |n| n}
          #   trackers = self_node.incoming(:friends).map{ |n| n}
          #   friends = trackers & trackings
          current_friends = self.friends 
          if current_friends && !current_friends.try(:empty?) 
            return current_friends.include?(tracked_node)
          else
            false
          end
        else
          false
        end
      end

      # Suggest friends: friends of friends
      def friend_suggestions
        # @@neo = Neography::Rest.new
        self_node = self.get_node
        if self_node
          recommendations = self_node.both(:friends).order("breadth first").uniqueness("node global").filter("position.length() == 2;").depth(2)
          all_recommendations = recommendations.map{|n| 
            begin
              n.object_type.safe_constantize.find(n[:object_id])
              # n.object_type.safe_constantize.find(n["object_id"])
            rescue Exception
            end
          }
        else
          false
        end
      end

      # Get all paths of entities between you and the entity (like linkedin)
      def all_degrees_of_separation(entity)
        if entity.is_a?(Sociographer::Entity)
          # @@neo = Neography::Rest.new
          self_node = self.get_node
          entity_node = entity.get_node
          if self_node && entity_node
            paths = []
            self_node.all_simple_paths_to(entity_node).incoming(:friends).depth(5).nodes.each do |path|
              # path << node.object_type.safe_constantize.find(node["object_id"])
              in_between = path.map{|n| begin n.object_type.safe_constantize.find(n[:object_id]).id rescue Exception end }
              path = {length: path.size-1, users: in_between}
              paths << path
              # puts "#{(path.size - 1)} degrees: " + path.map{|n| begin n.object_type.safe_constantize.find(n[:object_id]).name rescue Exception end }.join(" => friends =>") 
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
              # path << node.object_type.safe_constantize.find(node["object_id"])
            in_between = path.map{|n| begin n.object_type.safe_constantize.find(n[:object_id]).id rescue Exception end }
            path = {length: path.size-1, users: in_between}
            paths << path
            # puts "#{(path.size - 1)} degrees: " + path.map{|n| begin n.object_type.safe_constantize.find(n[:object_id]).name rescue Exception end }.join(" => friends =>") 
          end
          paths
        end
      end

      # To calculate a number representing the relation between you and the entity:
        # according to the weight of the relations, their magnitude, and their frequencies
        # according to each user
      def calculate_relation(entity)
        if entity.is_a?(Sociographer::Entity)
          # @@neo = Neography::Rest.new
          self_node = self.get_node
          entity_node = entity.get_node
          if self_node && entity_node
            # begin
            qur = "START r=rel(*) return distinct(type(r))"
            relations = @@neo.execute_query(qur)["data"].flatten
            all_relations = relations.map{|r| {"type" => r, "direction" => "all"}}
            all_rels_by_two_nodes = @@neo.get_paths(self_node, entity_node, all_relations, 2, "allPaths").select{ |l| l["length"] == 2}.map{ |u| u["relationships"]} # finds all paths between two nodes whose length == 2
            
            self_relations = all_rels_by_two_nodes.map{|u| u[0]}
            self_relations = self_relations.map{|r| Neography::Relationship.load(r.split("/").last) }.flatten.map{|u| u.rel_type} 
            self_relations = self_relations.group_by{|x|x}.map{|k,v| [k, v.length]}
            self_relations = self_relations.map{ |rel| self.relation_weight(rel[0])*rel[1] }.sum 

            entity_relations = all_rels_by_two_nodes.map{|u| u[1]}
            entity_relations = entity_relations.map{|r| Neography::Relationship.load(r.split("/").last) }.flatten.map{|u| u.rel_type} 
            entity_relations = entity_relations.group_by{|x|x}.map{|k,v| [k, v.length]}
            entity_relations = entity_relations.map{ |rel| entity.relation_weight(rel[0])*rel[1] }.sum 

            total_weight = self_relations+entity_relations
            # one_side.map{ |u| u["relationships"].map{ |r| @@neo.get_relationship_properties(r.split("/").last)["weight"] }  }.flatten.sum  
            # one_side = @@neo.get_shortest_weighted_path(self_node, entity_node, all_relations ).select{ |l| l["length"] < 3}
              # other_side = @@neo.get_shortest_weighted_path(entity_node, self_node, [{nil,"all"}]).select{ |l| l["length"] == 2}
              # return [*one_side,*other_side].map{|l| l["weight"]}.sum
            # rescue Exception
            #   return 0
            # end
          else
            false
          end
        else
          false
        end
      end
    
      # To sort the trackers according to "calculate_relation" method desendingly 
      def sorted_trackers
        ratings = []
        self.trackers.each do |user|
          ratings << {entity: user.id, weight: self.calculate_relation(user).to_i}
        end
        return ratings.sort_by{ |h| h[:weight] }.reverse
      end

      # To sort the tracking entities according to "calculate_relation" method desendingly 
      def sorted_tracking
        ratings = []
        self.tracking.each do |user|
          ratings << {entity: user.id, weight: self.calculate_relation(user).to_i}
        end
        return ratings.sort_by{ |h| h[:weight] }.reverse
      end

      # To sort the friends according to "calculate_relation" method desendingly 
      def sorted_friends
        ratings = []
        self.friends.each do |user|
          ratings << {entity: user.id, weight: self.calculate_relation(user).to_i}
        end
        return ratings.sort_by{ |h| h[:weight] }.reverse
      end
  
      # Call it to make the relation between the entity and the actionable
      def make_relation(actionable, relation, magnitude=1)
        if actionable.is_a?(Sociographer::Actionable) && relation.present? && relation
          # @@neo = Neography::Rest.new
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
            node_property = relation.to_s.parameterize.underscore.to_s+"_count"
            self_node_property = self_node[node_property]
            if self_node_property
              self_node[node_property] = self_node_property+1
            elsif
              self_node[node_property] = 1
            end
            relation = relation.to_s.parameterize.underscore.to_sym
            relation = Neography::Relationship.create(relation, self_node, actionable_node)
            @@neo.set_relationship_properties(relation, {"magnitude" => magnitude, "created_at" => DateTime.now.to_i})
            # self.update_actions_cache(self_node, relation, 1) #removed will be set to -1
            return true
          else
            false
          end
        else
          false
        end
      end

      # User's distinct relations with count
      def distinct_relations(from_cache=false)
        # @@neo = Neography::Rest.new
        begin
          if from_cache
            self_node = self.get_node
            @neo.get_node_properties(node1)
          else
            self_node_id = self.get_node_id
            qur = "start n=node("+self_node_id.to_s+") match n-[r]->() return distinct(type(r)), count(r), r.magnitude;"
            response = @@neo.execute_query(qur)
            distinct_relations = response["data"]
            return distinct_relations
          end
        rescue Exception
          return nil
        end
      end

      # User's specific relation with count // DONE
      def relation_count(relation)
        # @@neo = Neography::Rest.new
        self_node_id = self.get_node_id
        begin
          qur = "start n=node("+self_node_id.to_s+") match n-[r:"+relation+"]->() return count(r);"
          response = @@neo.execute_query(qur)
          relation_count = response["data"].try(:flatten).try(:first)
          return relation_count
        rescue Exception
          return nil
        end
      end

      # Calculates % of each relation from total relations count
      def relation_weight(relation)
        # @@neo = Neography::Rest.new
        # self_node_id = self.get_node_id 
        begin
          total_relations = self.distinct_relations
          if total_relations
            total_relations_weights = total_relations.map{|u| u[1]}.flatten.sum
            rel_count = total_relations.select{|u| u[0]==relation}.first
            rel_magnitude = rel_count[2]
            rel_count.empty? ? rel_count=0 : rel_count=rel_count[1]
            rel_count = rel_count.to_f
            total_relations_weights = total_relations_weights.to_f
            # rel_count = self.relation_count(relation)
            if ( !rel_magnitude || rel_magnitude > 0 )
              rel_magnitude = 1.0
            end
            if rel_count
              return ( (rel_count/total_relations_weights)*rel_magnitude )
            else
              return 0
            end
          else
            return 0
          end
        rescue Exception
          return 0
        end
      end


#### Distribution Methods
      
      def update_privacy_node
        
      end

      def trackers_privacy_list(max_needed_lists_count = 5)
        original_list = self.sorted_trackers
        original_weights_list = original_list.map{|u| u[:weight] }
        divided_array = sort_array(original_weights_list)
        returned_list = dist_arr(original_list, divided_array)
        needed_loops = returned_list.size - max_needed_lists_count
        if needed_loops > 0
          returned_list = recombine_array(returned_list, needed_loops)
        end
        return returned_list
      end
      def tracking_privacy_list(max_needed_lists_count = 5)
        original_list = self.sorted_tracking
        original_weights_list = original_list.map{|u| u[:weight] }
        divided_array = sort_array(original_weights_list)
        returned_list = dist_arr(original_list, divided_array)
        needed_loops = returned_list.size - max_needed_lists_count
        if needed_loops > 0
          returned_list = recombine_array(returned_list, needed_loops)
        end
        return returned_list
      end
      def friends_privacy_list(max_needed_lists_count = 5)
        original_list = self.sorted_friends
        original_weights_list = original_list.map{|u| u[:weight] }
        divided_array = sort_array(original_weights_list)
        returned_list = dist_arr(original_list, divided_array)
        needed_loops = returned_list.size - max_needed_lists_count
        if needed_loops > 0
          returned_list = recombine_array(returned_list, needed_loops)
        end
        return returned_list
      end

      def recombine_array(returned_list, needed_loops)
        for i in 0..(needed_loops-1)
          listed_diff = returned_list.each_with_index.map{|u,i| u[0][:weight]-returned_list[i-1][-1][:weight]}.drop(1)
          min_index = listed_diff.index(listed_diff.min)
          changed_item = returned_list[min_index].zip(returned_list[min_index+1]).flatten.compact
          returned_list = returned_list - [returned_list[min_index]] - [returned_list[min_index+1]]
          returned_list.insert(min_index, changed_item)
        end
        return returned_list
      end

      def sort_array(original_array)
        original_array.sort!
        division_arr = []
        original_array.each_with_index do |value,index|
          if index == 0
            division_arr << 1
          elsif index == original_array.size-1
            division_arr << -1
          else
            prev_div = (value - original_array[index-1]).abs
            next_div = (value - original_array[index+1]).abs
            if prev_div < next_div
              division_arr << -1
            else
              division_arr << 1
            end
          end
        end
        divided_array = fix_arr(division_arr)
        return divided_array
        # dist_array = dist_arr(original_array, divided_array)
      end


      def fix_arr(div_arr)
        returned_arr = ""
        div_arr.each_with_index do |val, index|
          if (val == -1) && (div_arr[index+1] == 1)
            returned_arr << "10"
          else
            returned_arr << "1"
          end
        end
        returned_arr = returned_arr.split("0").map{|u| u.split("")}
        return returned_arr
      end

      def dist_arr(original_array, fixed_array)
        returned_arr = []
        fixed_array.each do |arr|
          taken_elements = original_array.take(arr.size)
          original_array = original_array.drop(arr.size)
          returned_arr << taken_elements
        end
        return returned_arr
      end

## TO DO
 # b_hash = b.instance_variable_get("@categories")
 # y = {:Family => :Banned}
 # new_hash = Hash[b_hash.map {|k, v| [y[k]||k, v] }]
    end
  end
end