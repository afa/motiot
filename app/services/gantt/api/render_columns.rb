module Gantt
  module Api
    class RenderColumns
      include Dry::Transaction

      step :api_render_columns

      def api_render_columns(api:, query:)
        setting = Gantt::LoadIssueSetting.new.call(user: User.current)
        raise StandartError, setting.failure if setting.failure?

        api.grid_width setting.value!.column_settings&.fetch('grid_width', nil)

        api.array :columns do
          query.columns.each do |c|
            next if setting.value!.hide_dates &&
                    c.name.to_s.in?(%w[real_start real_end diff_start diff_end diff_duration])

            api_render_column api, c.name.to_s, caption: c.caption, setting: setting
          end
          unless setting.value!.hide_dates
            api_render_column api, 'real_start', setting: setting
            api_render_column api, 'real_end', setting: setting
            api_render_column api, 'diff_start', setting: setting
            api_render_column api, 'diff_end', setting: setting
            api_render_column api, 'diff_duration', setting: setting
          end
        end
        Success(:ok)
      end

      def api_render_column(api, name, caption: nil, setting: nil)
        width = setting.value!.column_settings&.fetch(name, nil) if setting.success?
        api.column do
          api.name name
          api.title caption || I18n.t("gantt.extended.columns.#{name}")
          api.width width.to_i if width
        end
      end
    end
  end
end
