module Gantt
  class LoadIssueSetting
    include Dry::Transaction

    step :load

    private

    def load(user:, project: nil, issue: nil, parent: nil)
      setting = GanttIssueSetting.where(
        user_id: user.id,
        project_id: project&.id,
        issue_id: issue&.id,
        parent_id: parent&.id
      ).first
      setting ||= GanttIssueSetting.create(
        user_id: user.id,
        project_id: project&.id,
        issue_id: issue&.id,
        parent_id: parent&.id
      )
      return Failure(error: 'Gantt setting can not be loaded') unless setting

      Success(setting)
    end
  end
end
