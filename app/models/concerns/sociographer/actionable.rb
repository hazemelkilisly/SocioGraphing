module Sociographer
  module Actionable
    extend ActiveSupport::Concern
    included do

      after_create :create_actionable
      before_destroy :ensure_deletion_fixes
      
      @@neo = Neography::Rest.new

      # Call-Back after Creation of Actionable (e.g. Post)
        # to create the corresponding node in neo4j DB
      def create_actionable
        Neography::Node.create("object_id" => self.id, "object_type" => self.class.to_s)
      end

      # Get only the id of the corresponding node to the actionable
      def get_node_id
        # @neo = Neography::Rest.new
        begin
          qur = "MATCH (n {object_id: "+self.id.to_s+", object_type: \'"+self.class.to_s+"\' }) RETURN n LIMIT 1"
          response = @@neo.execute_query(qur)
          node_id = response["data"].flatten.first["metadata"]["id"]
          return node_id
        rescue Exception
          return nil
        end
      end

      # Get the corresponding node to the actionable
      def get_node
        # @neo = Neography::Rest.new
        begin
          # qur = "MATCH (n {object_id: "+self.id.to_s+", object_type: \'"+self.class.to_s+"\' }) RETURN n LIMIT 1"
          # response = @neo.execute_query(qur)
          # node_id = response["data"].flatten.first["metadata"]["id"]
          node_id = self.get_node_id
          node = (node_id ? Neography::Node.load(node_id, @@neo) : nil)
          return node
        rescue Exception
          return nil
        end
      end

      # Object's distinct relations with count
      def distinct_relations(from_cache=false)
        # @@neo = Neography::Rest.new
        begin
          if from_cache
            self_node = self.get_node
            @neo.get_node_properties(node1)
          else
            self_node_id = self.get_node_id
            qur = "start n=node("+self_node_id.to_s+") match n<-[r]-() return distinct(type(r)), count(r), r.magnitude;"
            response = @@neo.execute_query(qur)
            distinct_relations = response["data"]
            return distinct_relations
          end
        rescue Exception
          return nil
        end
      end

      # To Ensure updating the cached relation index in all tracking entities' nodes
      def ensure_deletion_fixes
        begin
          actionable_node = self.get_node

          self_node_id = Post.first.get_node_id
          qur = "start n=node("+pni.to_s+") match n-[r]->() return distinct(type(r)), count(r), r.magnitude;"
          response = @@neo.execute_query(qur)
          distinct_relations = response["data"]


          if actionable_node
            actor_nodes = actionable_node.both.map{|u| u}
            actor_nodes.each do |an|
              an[]
            end
          else
            return nil
          end

        rescue
          return nil
        end
        # To Do  
      end
    end
  end
end