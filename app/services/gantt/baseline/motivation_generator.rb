require 'range'

module Gantt
  module Baseline
    class MotivationGenerator
      include Dry::Transaction

      START_EPOCH = Date.new(1970, 1, 1).freeze

      check :validate
      step :generate

      private

      def validate(user:, date_range:, amount:, requester:)
        true
      end

      def generate(user:, date_range:, amount:, requester:)
        projects_list = ::Motivation::BuildProjectsListForAuthorQuery.new(author: user, days: date_range.to_a)
        dates = date_range.to_a.sort
        auth = projects_list.authors_intervals.each_with_object({}) do |(prj, au_arr), obj|
          obj[prj] ||= Set.new
          au_arr.each do |au, intrvl|
            next unless au == user.id.to_s

            obj[prj] += trans_auth_dates(intrvl, dates)
            projects_list.report[:author][prj] ||= Set.new
            projects_list.report[:author][prj] += trans_auth_dates(intrvl, dates)
          end
        end
        projects_list.curator_intervals.each do |prj, cu_arr|
          cu_arr.each do |cu, intrvl|
            next unless cu == user.id.to_s

            auth[prj] ||= Set.new
            auth[prj] += trans_auth_dates(intrvl, dates)
            projects_list.report[:curator][prj] ||= Set.new
            projects_list.report[:curator][prj] += trans_auth_dates(intrvl, dates)
          end
        end

        # актуально - когда по запланированной рабочий статус или закрыто.
        # planned = projects_list.planned_project_issues_dates
        # dates_with_planed = {}

        rets = auth.each_with_object({}) do |(prj, set), obj|
          projects_list.report[:baseline][prj] ||= {}
          projects_list.report[:planned][prj] ||= {}
          projects_list.report[:real][prj] ||= {}
          projects_list.report[:closed][prj] ||= {}
          projects_list.report[:expired][prj] ||= {}
          projects_list.report[:result][prj] ||= {}

          real_planed = projects_list.project_issue_status3_days(prj).dig(prj) || {}
          set.each do |day|
            obj[day] ||= {}

            obj[day][prj] ||= Set.new
            obj[day][prj] = real_planed.key?(day) && real_planed[day].size.positive? && real_planed[day].all?(&:work)
            wd = Set.new((real_planed[day] || []).select(&:work).map(&:source_id))
            projects_list.report[:result][prj][day] = {
              issues: real_planed.fetch(day, []).reject { |x| x.status_id == 1 },
              work: real_planed.key?(day) &&
                    real_planed[day].size.positive? &&
                    real_planed[day].reject { |i| !i.work && i.source_id.in?(wd) }.all?(&:work)
            }
            projects_list.report[:baseline][prj][day] = Set.new(real_planed.fetch(day, []).map(&:baseline)).to_a
            projects_list.report[:planned][prj][day] = Set.new(
              real_planed.fetch(day, []).map { |x| { x.real_issue_id => x.plan_issue_id } }
            )
            projects_list.report[:real][prj][day] = Set.new(real_planed.fetch(day, [])
              .reject { |x| x.status_id.in?([1] + projects_list.closed_statuses_ids) }
              .map(&:real_issue_id))
            projects_list.report[:closed][prj][day] = Set.new(real_planed.fetch(day, [])
              .select { |x| x.status_id.in?(projects_list.closed_statuses_ids) }
              .map(&:real_issue_id))
            projects_list.report[:expired][prj][day] =
              Set.new(projects_list.report[:planned][prj][day].flat_map(&:keys)) -
              projects_list.report[:real][prj][day] -
              projects_list.report[:closed][prj][day]
          end
        end
        rets[:report] = projects_list.report
        Success(rets)
      end

      def trans_auth_dates(intrvl, dates)
        intrvl.flat_map do |item|
          sta = (item[:start] || dates.first).to_date
          sto = (item[:stop] || dates.last).to_date
          (sta..sto).to_a & dates
        end
      end
    end
  end
end
