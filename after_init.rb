app_dir = File.join(File.dirname(__FILE__), 'app')
ActiveSupport::Dependencies.autoload_paths << File.join(app_dir, 'queries')
ActiveSupport::Dependencies.autoload_paths << File.join(app_dir, 'services')
ActiveSupport::Dependencies.autoload_paths << File.join(app_dir, 'forms')
ActiveSupport::Dependencies.autoload_paths << File.join(app_dir, 'structs')

Rails.application.configure do
  config.reform.enable_active_model_builder_methods = true
  config.reform.validations = :dry
end
Redmine::MenuManager.map :top_menu do |menu|
  menu.push(:motivation, { controller: 'motivations', action: 'index' },
            caption: :label_motivation,
            # after: :documents,
            html: { class: 'icon icon-stats' },
            if: proc { User.current.allowed_to_globally?(:view_global_easy_gantt) })
end
RedmineExtensions::Reloader.to_prepare do
  # This access control is used by 4 plugins
  # Logic is also copied on easy_resource_base
  #
  # easy_gantt
  # easy_gantt_pro
  # easy_gantt_resources
  # easy_resource_base
  # easy_scheduler
  #
  Redmine::AccessControl.map do |map|
    map.project_module :motiot do |pmap|
      # View project level
      pmap.permission(:view_easy_gantt, {
                        motivations: %i[index create]
                        # gantt_settings: %I[index create],
                        # easy_gantt: %i[index issues projects issues_up issues_down toggle_dates
                        #                issues_open issues_close motivation_report create_motivation_report],
                        # easy_gantt_pro: %i[lowest_progress_tasks cashflow_data motivation_report
                        #                    create_motivation_report],
                        # easy_gantt_resources: %i[index project_data users_sums projects_sums allocated_issues
                        #                          issue_up issue_down toggle_dates motivation_report
                        #                          create_motivation_report]
                        # easy_gantt_reservations: [:index]
                      }, read: true, global: true, require: :member)
    end
  end
end
