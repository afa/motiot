module Gantt
  module Api
    class RenderIssues
      include Dry::Transaction

      FIELD_FORMATS = {
        'string' => 'text',
        'int' => 'integer'
      }.freeze
      EDITABLES = {
        subject: {
          format: 'text',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :subject, format: :json) }
        },
        assigned_to: {
          format: 'select',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :assigned_to, format: :json) },
          source: ->(iss) { Rails.application.routes.url_helpers.allowed_zaoeps_gantt_path(iss, entity: :assigned_to, format: :json) }
        },
        start_date: {
          format: 'date',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :start_date, format: :json) }
        },
        project: {
          format: 'select',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :project, format: :json) },
          source: ->(iss) { Rails.application.routes.url_helpers.allowed_zaoeps_gantt_path(iss, entity: :project, format: :json) }
        },
        status: {
          format: 'date',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :status, format: :json) },
          source: ->(iss) { Rails.application.routes.url_helpers.allowed_zaoeps_gantt_path(iss, entity: :status, format: :json) }
        },
        priority: {
          format: 'select',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :priority, format: :json) },
          source: ->(iss) { Rails.application.routes.url_helpers.allowed_zaoeps_gantt_path(iss, entity: :priority, format: :json) }
        },
        author: {
          format: 'date',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :author, format: :json) },
          source: ->(iss) { Rails.application.routes.url_helpers.allowed_zaoeps_gantt_path(iss, entity: :author, format: :json) }
        },
        done_ratio: {
          format: 'integer',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :done_ratio, format: :json) }
        },
        estimated_hours: {
          format: 'float',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :estimated_hours, format: :json) }
        },
        due_date: {
          format: 'date',
          url: ->(iss) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :due_date, format: :json) }
        },
        custom: {
          format: ->(_iss, field) { field.field_format },
          url: ->(iss, field) { Rails.application.routes.url_helpers.zaoeps_gantt_path(iss, entity: :"cf_#{field.id}", format: :json) }
        }
        # subject start_date end_date
      }.freeze

      step :api_render_issues

      private

      def api_render_issues(api:, issues:, project:, query:, with_columns:)
        sort_issues_by_position(issues)
        alt = check_alternative_issues(project, issues)
        track = project.tracker_setting&.tracker_id
        Success(
          api.array(:issues) do
            issues.each do |issue|
              api.issue do
                if alt && issue.tracker_id == track
                  api.style do
                    api.bold alt['bold']
                    api.italic alt['italic']
                    api.underline alt['underline']
                    api.color alt['color']
                  end
                end
                api_assign_issue_fields(api, issue, query)

                if EasySetting.value(:easy_gantt_show_task_soonest_start) && project.nil?
                  api.soonest_start issue.soonest_start
                end

                api.latest_due issue.latest_due if EasySetting.value(:easy_gantt_show_task_latest_due) && project.nil?

                api.is_planned issue.project&.is_planned.present? || false

                api.permissions { api.editable issue.gantt_editable? }

                fill_columns(api, issue, query, with_columns)
              end
            end
          end
        )
      end

      def editable_api(api, issue, column)
        name = column.name.to_sym
        if EDITABLES[name]
          api.item do
            api.name column.name
            api.format EDITABLES[name][:format]
            api.url EDITABLES[name][:url]&.call(issue)
            api.source_url EDITABLES[name][:source]&.call(issue)
            api.ac_source_url EDITABLES[name][:ac_source_url]&.call(issue)
          end
        elsif column&.custom_field
          api.item do
            api.name column.name
            api.format FIELD_FORMATS[column.custom_field.field_format] || column.custom_field.field_format
            api.url EDITABLES[:custom][:url]&.call(issue, column.custom_field)
            api.source_url EDITABLES[:custom][:source_url]&.call(issue, column.custom_field)
            api.ac_source_url EDITABLES[:custom][:ac_source_url]&.call(issue, column.custom_field)
          end
        end
      end

      def check_alternative_issues(project, issues)
        track_id = project.tracker_setting&.tracker_id
        return false unless track_id

        return false unless issues.any? { |issue| issue.tracker_id != track_id }

        return false unless issues.any? { |issue| issue.tracker_id == track_id }

        project.tracker_setting.tracker_settings
      end

      def api_progress_fields(api, issue)
        api.start_date issue.start_date
        api.due_date issue.due_date
        api.estimated_hours issue.estimated_hours
        api.done_ratio issue.done_ratio
      end

      def api_assign_issue_fields(api, issue, query)
        api.id issue.id
        api_progress_fields(api, issue)
        api.fixed_version_id issue.fixed_version_id
        api.project_id issue.project_id
        api.tracker_id issue.tracker_id
        api.priority_id issue.priority_id
        api.status_id issue.status_id
        api.assigned_to_id issue.assigned_to_id
        api.links issue.links
        api.name issue.subject
        api.closed issue.closed?
        api.overdue issue.overdue?
        api.parent_issue_id issue.parent_id
        api.array(:editable) do
          query.columns.each do |col|
            editable_api(api, issue, col)
          end
        end
        api.show_children !Gantt::LoadIssueSetting
          .new
          .call(user: User.current, issue: issue, project: issue.project)
          .value_or(nil)&.hide_children || 0
        api.position issue.fetch_position(for_user: User.current) || 999_999
      end

      def sort_issues_by_position(issues)
        return if issues.blank?

        issues.each { |i| i.links = %i[up down] }
        grouped = issues.group_by { |issue| [issue.parent_id, issue.project_id] }
        grouped.values.each do |gr|
          srt = gr.sort_by { |issue| issue.fetch_position(for_user: User.current) || 999_999 }
          srt.first.links.delete(:up)
          srt.last.links.delete(:down)
        end
      end

      def api_column(api, name, value)
        api.column do
          api.name name
          api.value value
        end
      end

      def diff_date_format(days)
        return '---' unless days

        sign = days <=> 0
        abs = days.abs
        case abs
        when 0..6
          "#{(abs * sign)} дней"
        when 7..29
          "#{(sign * abs / 7).to_i} нед.#{(abs % 7).zero? ? '' : format(' и %<rem>d дн.', rem: abs % 7)}"
        else
          "#{(sign * abs / 30).to_i} мес.#{(abs % 30).zero? ? '' : format(' и %<rem>d дн.', rem: abs % 30)}"
        end
      end

      def fill_duration_columns(api, timings)
        api_column(api, :diff_start, diff_date_format(timings.diff_start))
        api_column(api, :diff_end, diff_date_format(timings.diff_end))
        api_column(api, :diff_duration, diff_date_format(timings.diff_duration))
      end

      def fill_dates_columns(api, issue)
        setting = Gantt::LoadIssueSetting.new.call(user: User.current)
        raise StandartError, setting.failure if setting.failure?

        return if setting.value!.hide_dates

        timings = Gantt::Utility::CalcIssueTimings.new.call(issue: issue).value_or(OpenStruct.new)

        fill_start_end_columns(api, issue, timings)
        fill_duration_columns(api, timings)
      end

      def fill_start_end_columns(api, issue, timings)
        api_column(
          api, :real_start,
          Gantt::Utility::FormatColumn.new.call(entity: issue, column: nil, value: (timings.real_start || '---')).value!
        )
        api_column(
          api, :real_end,
          Gantt::Utility::FormatColumn.new.call(entity: issue, column: nil, value: (timings.real_end || '---')).value!
        )
      end

      def fill_columns(api, issue, query, _with_columns)
        api.array :columns do
          setting = Gantt::LoadIssueSetting.new.call(user: User.current)
          raise StandartError, setting.failure if setting.failure?

          query.columns.each do |c|
            next if setting.value!.hide_dates &&
                    c.name.to_s.in?(%w[real_start real_end diff_start diff_end diff_duration])

            api_column(api, c.name, Gantt::Utility::FormatColumn.new.call(
              entity: issue, column: c, value: c.value(issue)
            ).value_or(''))
          end
          fill_dates_columns(api, issue)
        end
      end
    end
  end
end
