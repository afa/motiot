module Gantt
  module Api
    class RenderProjects
      include Dry::Transaction

      step :api_render_projects

      private

      def api_render_projects(api:, projects:, query:, all_project_tree: nil, with_columns: false)
        projects_issues_counts = Issue.visible.gantt_opened.where(project_id: projects).group(:project_id).count(:id)
        api.array :projects do
          projects.each do |project|
            api.project do
              standart_fields(api, project)

              # Schema
              api.status_id project.status
              api.priority_id project&.easy_priority_id

              api.permissions do
                api.editable project.gantt_editable?
              end

              api.done_ratio project.gantt_completed_percent if EasySetting.value(:easy_gantt_show_project_progress)

              api.issues_count projects_issues_counts[project.id] if projects_issues_counts&.key?(project.id)

              api.has_subprojects true if all_project_tree&.any? { |lft, rgt| lft > project.lft && rgt < project.rgt }

              if with_columns
                api.array :columns do
                  query.columns.each do |c|
                    render_column(api, c, project)
                  end
                end
              end
            end
          end
        end
        Success(:ok)
      end

      def render_column(api, column, project)
        api.column do
          api.name column.name
          api.value(
            Gantt::Utility::FormatColumn.new.call(
              entity: project, column: column, value: column.value(project)
            ).value_or('')
          )
        end
      end

      def standart_fields(api, project)
        api.id project.id
        api.name project.name
        api.start_date project.gantt_start_date || Time.zone.today
        api.due_date project.gantt_due_date || Time.zone.today
        api.parent_id project.parent_id
        api.is_baseline project&.easy_baseline_for_id?
      end
    end
  end
end
