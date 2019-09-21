module Gantt
  module Api
    class RenderScheme
      include Dry::Transaction

      step :api_render_scheme

      def api_render_scheme(api:, table:)
        if table.is_a?(Symbol)
          return Failure(:undefined) unless Object.const_defined?(table)

          table = Object.const_get(table)
        end

        return Failure(:invalid_table) unless table.column_names.include?('easy_color_scheme')

        records = table.where.not(easy_color_scheme: ['', nil]).pluck(:id, :easy_color_scheme)
        # col = table.arel_table[:easy_color_scheme]
        # records = table.where(col.not_eq(nil).and(col.not_eq(''))).pluck(:id, :easy_color_scheme)

        api.array table.to_s do
          records.each do |id, scheme|
            api.entity do
              api.id id
              api.scheme scheme
            end
          end
        end
        Success(:ok)
      end
    end
  end
end
