module Gantt
  module Baseline
    class ProjectsDayActuality
      include Dry::Transaction

      step :calc

      private

      def calc(date:, projects:)
        data = projects.each_with_object({}) do |prj, obj|
          obj[prj.id] ||= {}
          obj[prj.id][:worked] = Gantt::Baseline::SingleProjectDayActuality
            .new
            .call(project: prj, date: date)
            .value_or(false)
        end
        data[:projects] = data.keys
        data[:projects_total] = data[:projects].size
        data[:projects_active] = data[:projects].select { |id| data.dig(id, :worked) }.size
        Success(data)
      end
    end
  end
end
