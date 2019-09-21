module Gantt
  module Baseline
    class BaselineForProject < Base
      property :project_id
      property :baseline_id

      def save
        project = Project.find(project_id)
        baseline = project.easy_baselines.find(baseline_id)
        Gantt::Baseline::SaveIssuesDates.new.call(baseline: baseline)
      end
    end
  end
end
