module Gantt
  module Api
    class RenderRelations
      include Dry::Transaction

      step :api_render_relations

      def api_render_relations(api:, relations:)
        api.array :relations do
          relations.each do |rel|
            api.relation do
              api.id rel.id
              api.source_id rel.issue_from_id
              api.target_id rel.issue_to_id
              api.type rel.relation_type
              api.delay rel.delay.to_i
            end
          end
        end
        Success(:ok)
      end
    end
  end
end
