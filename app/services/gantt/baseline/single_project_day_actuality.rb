module Gantt
  module Baseline
    class SingleProjectDayActuality
      include Dry::Transaction

      step :calc_project_date_actuality

      private

      def calc_project_date_actuality(project:, date:)
        bases = project.easy_baselines
        if bases.present?
          actual_result = Gantt::Baseline::ActualBaselineForDate.new.call(
            project: project,
            baselines: bases,
            date: date
          )
          return Failure(actual_result.failure) if actual_result.failure?

          actual_baseline = actual_result.value!
          iss_actual = actual_baseline.easy_baseline_sources.each_with_object([]) do |bas, set|
            set << calc_actual(bas, date)
          end
          Success(iss_actual.flatten.all?)
        else
          # base_actual = project.issues
          #   .includes({ journals: :details }, :status, :author, :assigned_to).each_with_object([]) do |issue, set|
          #   timings = Gantt::Utility::CalcIssueTimings.new.call(issue: issue).value!
          #   set << actual_base_plan(timings, date)
          # end
          Success(false)
        end
      end

      def actual_base_plan(bas, date)
        # dest == plan
        src_start = bas.real_start || Time.zone.today
        dest_start = bas.start_date || Time.zone.today
        return [] if dest_start > date && src_start > date

        dest_due = bas.due_date || Time.zone.today
        src_due = bas.real_start || Time.zone.today
        return [] if dest_due < date && src_due < date

        [!date_in?(dest_due, src_due, date), !date_in?(dest_start, src_start, date), true]
      end

      def calc_actual(bas, date)
        src_start = bas.source.start_date || Time.zone.today
        dest_start = bas.destination.start_date || Time.zone.today
        return [] if dest_start > date && src_start > date

        dest_due = bas.destination.due_date || Time.zone.today
        src_due = bas.source.due_date || Time.zone.today
        return [] if dest_due < date && src_due < date

        [!date_in?(dest_due, src_due, date), !date_in?(dest_start, src_start, date), true]
      end

      def date_in?(dest, src, date)
        dest < src && dest < date && date <= src
      end
    end
  end
end
