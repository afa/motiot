module Gantt
  module Api
    class RenderVersions
      include Dry::Transaction

      step :api_render_versions

      def api_render_versions(api:, versions:)
        return Failure(:empty) if versions.blank?

        api.array :versions do
          versions.each do |version|
            api.version do
              api.id version.id
              api.name version.name
              api.start_date version.effective_date
              api.project_id version.project_id
              api.status version.status
              api.permissions do
                api.editable version.gantt_editable?
              end
            end
          end
        end
        Success(:ok)
      end
    end
  end
end
