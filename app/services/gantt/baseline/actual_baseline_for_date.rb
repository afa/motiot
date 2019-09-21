module Gantt
  module Baseline
    class ActualBaselineForDate
      include Dry::Transaction

      step :run

      private

      def run(project:, date:, baselines:)
        sorted = baselines.sort_by { |base| base.zaoeps_baseline_start_date || base.created_on }
        actual = sorted.select { |prj| (prj.zaoeps_baseline_start_date || prj.created_on).to_date <= date }.last
        return Success(actual) if actual

        Failure(:not_found_actual_baseline)
      end
    end
  end
end
