module Gantt
  class Motivation < Gantt::Base
    property :user, transform_with: ->(val) { User.find_by(id: val) }
    property :amount, transform_with: ->(val) { val.to_f }
    property :date_from, transform_with: ->(val) { Date.parse(val) }
    property :date_to, transform_with: ->(val) { Date.parse(val) }

    def data
      return nil unless user && date_from && date_to

      @data ||= Gantt::Baseline::MotivationGenerator.new.call(
        user: user, date_range: date_from..date_to, amount: amount, requester: User.current
      )
    end

    def projects
      return nil unless user && date_from && date_to

      @projects ||= data
        .value_or({})
        .reject { |k, _v| k.is_a?(Symbol) }
        .values
        .flat_map(&:keys)
        .compact
        .uniq
        .map { |id| Project.find(id) }
    end

    def report
      @report ||= data&.value_or({})&.delete(:report)
    end
  end
end
