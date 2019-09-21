class MotivationForm < BaseForm
  property :user, type: User
  property :amount, type: Float
  property :date_from, type: Date
  property :date_to, type: Date
  property :data, writeable: false, populator: :data_populate!
  property :projects, writeable: false, populator: :projects_populate!
  property :report, writeable: false, populator: :report_populate!

  validation :default, with: { form: true } do
    required(:user).filled
    required(:amount).filled
    required(:date_from).filled
    required(:date_to).filled
  end

  def report_populate!
    model.report
  end

  def data_populate!
    model.data
  end

  def projects_populate!
    model.projects
  end
  # unless motivation_params[:date_from].present? && motivation_params[:date_to].present?
end
