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

      # To Ensure updating the cached relation index in all tracking entities' nodes
      def ensure_deletion_fixes

        # To Do  
      end
    end
  end
end