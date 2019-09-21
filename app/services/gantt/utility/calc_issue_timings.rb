module Gantt
  module Utility
    class CalcIssueTimings
      include Dry::Transaction

      step :calc

      private

      def calc(issue:)
        data = OpenStruct.new
        data.real_start = calc_real_start(issue)
        data.real_end = calc_real_end(issue)
        data.start_date = planned_start(issue)
        data.due_date = planned_end(issue)
        data.diff_start = calc_diff_start(data.start_date, data.real_start)
        data.diff_end = calc_diff_end(data.due_date, data.real_end)
        data.diff_duration = calc_diff_duration(data.start_date, data.due_date, data.real_start, data.real_end)
        Success(data)
      end

      def calc_real_start(issue)
        issue.journals.flat_map(&:details).select do |x|
          x.prop_key == 'status_id' &&
            x.old_value.in?(IssueStatus.where(is_closed: false).ids) &&
            x.value.in?(IssueStatus.where(is_closed: false).ids)
        end.first&.journal&.created_on || Time.zone.today
      end

      def calc_real_end(issue)
        if issue.closed?
          issue.journals.flat_map(&:details)
            .select { |x| x.prop_key == 'status_id' && x.value.in?(IssueStatus.where(is_closed: true).ids) }
            .last&.journal&.created_on
        else
          Time.zone.today
        end
      end

      def planned_start(issue)
        field = IssueCustomField.find_by(name: I18n.t('easy_gantt_pro.baselines.name_plan_start_date'))
        return nil unless field

        val = issue.custom_values.find_by(custom_field_id: field.id)
        return nil unless val

        Date.parse(val.value) rescue nil
      end

      def planned_end(issue)
        field = IssueCustomField.find_by(name: I18n.t('easy_gantt_pro.baselines.name_plan_end_date'))
        return nil unless field

        val = issue.custom_values.find_by(custom_field_id: field.id)
        return nil unless val

        Date.parse(val.value) rescue nil
      end

      def calc_diff_start(planned_start, real_start)
        return nil unless planned_start && real_start

        # user = issue.assigned_to || issue.author
        delta = real_start - planned_start
        delta + (delta <=> 0)
        # user
        #   .available_working_hours_between(issue.start_date.to_date, real_start.to_date)
        #   .values
        #   .select { |num| num > 0.0 }
        #   .size
      end

      def calc_diff_end(planned_end, real_end)
        return nil unless real_end && planned_end

        delta = real_end - planned_end
        delta + (delta <=> 0)
        # user = issue.assigned_to || issue.author
        # user
        #   .available_working_hours_between(issue.due_date.to_date, real_end.to_date)
        #   .values
        #   .select { |num| num > 0.0 }
        #   .size
      end

      def calc_diff_duration(planned_start, planned_end, real_start, real_end)
        return nil unless real_start && real_end

        return nil unless planned_start && planned_end

        real = real_end - real_start
        planned = planned_end - planned_start
        delta = real - planned
        delta + (delta <=> 0)
      end

      # def real_start_end(issue)
      #   [calc_real_start(issue), calc_real_end(issue)]
      # end

      # def diff_start_end_duration(issue, real_start, real_end)
      #   diff_start = calc_diff_start(issue, real_start)
      #   diff_end = calc_diff_end(issue, real_end)
      #   [diff_start, diff_end, calc_diff_duration(issue, real_start, real_end)]
      # end
    end
  end
end
