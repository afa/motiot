module Gantt
  module Baseline
    class SaveIssuesDates
      include Dry::Transaction

      map :select_issues
      step :drop_absent
      map :take_dates
      step :save

      private

      def select_issues(baseline:)
        { sources: baseline.easy_baseline_sources.issues, baseline: baseline }
      end

      def drop_absent(baseline:, sources:)
        start_field = make_field(I18n.t('easy_gantt_pro.baselines.name_plan_start_date'))
        end_field = make_field(I18n.t('easy_gantt_pro.baselines.name_plan_end_date'))
        to_drop = baseline.easy_baseline_for.issues - sources.map(&:source)
        to_drop.each do |issue|
          issue.custom_values.find_by(custom_field_id: start_field.id)&.destroy
          issue.custom_values.find_by(custom_field_id: end_field.id)&.destroy
        end
        Success(sources: sources)
      end

      def take_dates(sources:)
        { data: sources.map { |src| [src.source, src.destination.start_date, src.destination.due_date] } }
      end

      def save(data:)
        start_field = make_field(I18n.t('easy_gantt_pro.baselines.name_plan_start_date'))
        end_field = make_field(I18n.t('easy_gantt_pro.baselines.name_plan_end_date'))
        ok = data.each_with_object([]) do |(issue, start, due), result|
          result << make_value(issue, start_field, start)
          result << make_value(issue, end_field, due)
        end
        return Success(:ok) if ok.all?

        Failure('ERROR_SAVING_CUSTOM_FIELDS')
      end

      def make_field(name)
        field = IssueCustomField.find_by(name: name)
        return field if field

        field = IssueCustomField.create(
          name: name,
          is_for_all: true,
          easy_custom_permissions: {
            'special_visibility' => '0',
            'allowed_easy_user_type_ids' => [''],
            'allowed_group_ids' => [''],
            'allowed_user_ids' => ['']
          },
          field_format: 'date'
        )
        field.tracker_ids = Tracker.ids
        field.save
        field
      end

      def make_value(issue, field, date)
        val = issue.custom_values.find_by(custom_field_id: field.id)
        val ||= issue.custom_values.create(custom_field_id: field.id, value: date.to_s(:db))
        val.update(value: date.to_s(:db))
      end
    end
  end
end
