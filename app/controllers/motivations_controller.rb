class MotivationsController < ApplicationController
  CURATOR_FIELD = 'Куратор проекта'.freeze

  # menu_item :easy_gantt

  before_action :authorize_global
  before_action :load_users

  def index
    return render_403 unless User.current.allowed_to_globally?(:view_global_easy_gantt)

    @motivation = MotivationForm.new(Gantt::Motivation.new)
    render action: :index, content_type: 'text/html'
  end

  def create
    return render_403 unless User.current.allowed_to_globally?(:view_global_easy_gantt)

    @motivation = MotivationForm.new(Gantt::Motivation.new(motivation_params))
    return redirect_to motivations_path unless @motivation.validate(motivation_params)

    @report = @motivation.report
    respond_to do |format|
      format.html { render }
      # format.xlsx do
      #   send_data(
      #     Gantt::Utility::ExportToXlsx.new.call(
      #       user: @motivation.model.user,
      #       amount: @motivation.model.amount,
      #       date_from: @motivation.model.date_from,
      #       date_to: @motivation.model.date_to
      #     ).value_or(''),
      #     filename: get_export_filename(:xlsx, @query, l(:heading_easy_helpdesk_projects_index))
      #   )
      # end
    end
  end

  private

  def motivation_params
    params[:motivation] || {}
  end

  def load_users
    kp_id = ProjectCustomField.find_by(name: CURATOR_FIELD)&.id
    details = JournalDetail.joins(:journal).where(journals: { journalized_type: 'Project' })
    user_ids = details.where(property: 'cf', prop_key: kp_id).pluck('distinct value') +
               details.where(property: 'cf', prop_key: kp_id).pluck('distinct old_value') +
               details.where(property: 'attr', prop_key: 'author_id').pluck('distinct value') +
               details.where(property: 'attr', prop_key: 'author_id').pluck('distinct old_value')
    @users = User.where(id: user_ids)
  end
end
