module Motivation
  module Curators
    def authors_select_sql
      <<-SQL
        with authors_hist(prj, date, befor, after) as (
          select
            journals.journalized_id as prj,
            journals.created_on as date,
            cast(journal_details.old_value as char character set utf8) as befor,
            cast(journal_details.value as char character set utf8) as after
          from journal_details
          inner join journals on journals.id = journal_details.journal_id
          inner join projects on journals.journalized_type = 'Project'
            and projects.id = journals.journalized_id
          where journal_details.property = 'attr' and journal_details.prop_key = 'author_id'
            and projects.status != 9 and projects.parent_id is null
            and (journal_details.old_value = '#{author.id}' or journal_details.value = '#{author.id}')
        ),
        authors_now(prj, date, befor, after) as (
          select projects.id as prj,
          cast(null as datetime) as date,
          cast(null as char character set utf8) as befor,
          cast(null as char character set utf8) as after
          from projects
          where projects.id not in (select prj from authors_hist) and projects.author_id = #{author.id}
            and projects.status != 9 and projects.parent_id is null
        )
        select * from authors_hist
        union
        select * from authors_now
      SQL
    end

    def authors_select
      query_select(:authors_select_sql).rows
    end

    def curator_select
      query_select(:curator_select_sql).rows
    end

    def curator_select_sql
      @curator_field_id ||= ProjectCustomField.find_by(name: 'Куратор проекта')&.id
      return nil unless @curator_field_id

      <<-SQL
        with curators_hist as (
          select
            journals.journalized_id prj,
            journals.created_on date,
            cast(journal_details.old_value as char character set utf8) as befor,
            cast(journal_details.value as char character set utf8) as after
          from journal_details
          inner join journals on journals.id = journal_details.journal_id
          inner join projects on journals.journalized_type = 'Project'
            and projects.id = journals.journalized_id
          inner join custom_values on projects.id = custom_values.customized_id
            and custom_values.customized_type = 'Project'
          where journal_details.property = 'cf' and journal_details.prop_key = '#{@curator_field_id}'
            and projects.status != 9 and projects.parent_id is null
            and (journal_details.old_value = '#{author.id}' or journal_details.value = '#{author.id}')
        ),
        curators_now as (
          select projects.id prj,
          cast(null as datetime ) date,
          cast(null as char character set utf8) befor,
          cast(null as char character set utf8) after
          from projects
          inner join custom_values on custom_values.customized_id = projects.id
          inner join custom_fields on custom_values.custom_field_id = custom_fields.id
          where projects.id not in (select prj from curators_hist) and custom_values.value = '#{author.id}'
        )
        select * from curators_hist
        union
        select * from curators_now
      SQL
    end

    def curator_intervals
      # prj -> auth -> [{start:, stop:, item:}]
      curator_select.group_by(&:first).each_with_object({}) do |(prj, grp), obj|
        calc_intervals(grp, prj, obj)
      end
    end

    def authors_intervals
      # prj -> auth -> [{start:, stop:, item:}]
      authors_select.group_by(&:first).each_with_object({}) do |(prj, grp), obj|
        calc_intervals(grp, prj, obj)
      end
    end

    def calc_intervals(grp, prj, obj)
      grp.sort_by(&:second).each do |item|
        obj[prj] ||= {}
        tkey = item.third || author.id.to_s
        obj[prj][tkey] ||= []
        ls = obj[prj][tkey].last
        if ls
          ls[:stop] = item.second
        else
          obj[prj][tkey] << { item: item.third, start: nil, stop: item.second }
        end

        lkey = item.last || author.id.to_s
        obj[prj][lkey] ||= []
        obj[prj][lkey] << { item: item.last, start: item.second, stop: nil }
      end
    end
  end

  module Planned
    def dates_with_start_select
      query_select(:dates_with_start_sql).rows
    end

    def baselines_project_dates
      # returns hash (prj => hash (date => baseline))
      @baselines_project_dates ||= dates_with_start_select.each_with_object({}) do |item, obj|
        obj[item.last] ||= {}
        obj[item.last][item.first.to_date] = item.third
        @report[:baseline][item.last] ||= {}
        @report[:baseline][item.last][item.first.to_date] = item.third
      end
    end

    # def planned_project_issues_dates
    #   @planned_project_issues_dates ||= baselines_project_dates.each_with_object({}) do |(prj, date_bases), obj|
    #     obj[prj] ||= {}
    #     date_bases.each do |date, base|
    #       line = project(base)
    #       line.easy_baseline_sources.each do |src|
    #         next unless src.relation_type == 'Issue'

    #         next unless issue(src.destination_id)&.tracker_id&.in?(@tracker_ids)

    #         start = issue(src.destination_id)&.start_date
    #         next unless start

    #         start = [start, line.zaoeps_baseline_start_date || line.created_on.to_date].max
    #         next unless date.between?(
    #           start,
    #           issue(src.destination_id)&.due_date || Time.zone.today.to_date
    #         )

    #         obj[prj][date] ||= Set.new
    #         obj[prj][date] << { src.source_id => src.destination_id }
    #       end
    #     end
    #   end
    # end

    def dates_with_start_sql
      <<-SQL
        select cdate, max(start) as start, max(baseline) as baseline, project_id from (
          with recursive dates as (
            select cast('#{@days.first.to_s(:db)}' as date) cdate
            union all
            select cdate + interval 1 day from dates
              where cdate < cast('#{@days.last.to_s(:db)}' as date)
          ),
          bases(start, baseline, project_id) as (
            select
              coalesce(zaoeps_baseline_start_date, cast(created_on as date)) as start,
              projects.id as baseline,
              projects.easy_baseline_for_id as project_id
            from projects
              where
                easy_baseline_for_id is not null
          ) select dates.cdate cdate, bases.start start, bases.baseline baseline, bases.project_id project_id from dates
            inner join bases
              on dates.cdate >= bases.start
        ) t group by t.project_id, t.cdate;
      SQL
    end
  end

  module Reals
    def real_work_without_status(project_id, status_ids)
      # date -> Set(iss)
      project_issue_status3_days(project_id).each_with_object({}) do |(iss, hsh), obj|
        hsh.each do |day, data|
          obj[day] ||= Set.new
          obj[day] << iss unless status_ids.include?(data.status_id.to_i)
        end
      end
    end

    def calc_real_work_or_closed(project)
      # returns Hash {date -> [issue_ids],...}
      @work_or_closed_days ||= {}
      @work_or_closed_days[project.id] ||= real_work_without_status(project.id, [1])
    end

    def calc_real_work(project)
      # returns Hash {date -> [issue_ids],...}
      @work_days ||= {}
      @work_days[project.id] ||= real_work_without_status(project.id, @closed_statuses_ids + [1])
    end
  end

  class BuildProjectsListForAuthorQuery
    attr_reader :author, :tracker_ids, :report, :closed_statuses_ids
    include Curators
    include Planned
    include Reals

    def initialize(author:, days: [])
      @report = { author: {}, curator: {}, baseline: {}, planned: {}, real: {}, closed: {}, expired: {}, result: {} }
      @author = author
      @tracker_ids = Tracker
        .where(name: ['Основная задача проекта', 'Основная задача проекта ПВТ', 'Основная задача(закрытая)'])
        .ids
      @closed_statuses_ids ||= IssueStatus.where(is_closed: true).ids # closed and new
      @days = days.to_a.sort
    end

    def call; end

    def query_explain_param(method_sym, param)
      sql = method(method_sym).call(param)
      return [] if sql.nil?

      # ActiveRecord::Base.connection_pool.with_connection { |conn| conn.exec_query('analyze format=json ' + sql) }
      ActiveRecord::Base.connection_pool.with_connection { |conn| conn.exec_query('analyze ' + sql) }
    end

    def query_select_param(method_sym, param)
      sql = method(method_sym).call(param)
      return [] if sql.nil?

      ActiveRecord::Base.connection_pool.with_connection { |conn| conn.exec_query(sql) }
    end

    def query_select(method_sym)
      sql = method(method_sym).call
      return [] if sql.nil?

      ActiveRecord::Base.connection_pool.with_connection { |conn| conn.exec_query(sql) }
    end

    def sort_items_nils(les, mor)
      return -1 if les.first.nil?

      return 1 if mor.first.nil?

      les.first <=> mor.first
    end

    def project_issue_status3_days(prj)
      project_issue_status_intervals3_select(prj).each_with_object({}) do |item, obj|
        obj[item.project_id] ||= {}
        obj[item.project_id][item.day] ||= Set.new
        obj[item.project_id][item.day] << item
      end
    end

    def issue(id)
      @issues ||= {}
      @issues[id] ||= Issue.find_by(id: id)
    end

    def project(id)
      @projects ||= {}
      @projects[id] ||= Project.find(id)
    end

    def project_issue_status_intervals3_explain(project)
      query_explain_param(:project_issue_status_intervals3_sql, project)
    end

    def project_issue_status_intervals3_select(project)
      iss = query_select_param(:project_issue_status_intervals3_sql, project).to_a.map do |row|
        Motivations::IssueStatusDaysStruct.new row
      end
      db = Set.new(iss.map { |i| [i.project_id, i.day, i.baseline] })
      data = query_select(:dates_with_start_sql).to_a.map do |row|
        Motivations::IssueStatusDaysStruct
          .new(day: row['cdate'], start: row['start'],
               project_id: row['project_id'], baseline: row['baseline'], work: 1)
      end
      data.reject { |i| [i.project_id, i.day, i.baseline].in?(db) } + iss
    end

    private

    def project_issue_status_intervals3_sql(project)
      <<-SQL
        with recursive params(project, date_start, date_stop) as (
          select
            #{project} project,
            cast('#{@days.first.to_s(:db)}' as date) date_start,
            cast('#{@days.last.to_s(:db)}' as date) date_stop
        ),
        closed_statuses(id) as (
          select id from issue_statuses where is_closed is true
        ),
        dates(cdate) as (
          select (select date_start from params) cdate
          union all
          select cdate + interval 1 day from dates
            where cdate < (select date_stop from params)
        ),
        bases(start, baseline, project_id) as (
          select
            coalesce(zaoeps_baseline_start_date, cast(created_on as date)) start,
            id baseline,
            easy_baseline_for_id as project_id
          from projects
            where easy_baseline_for_id is not null
        ),
        base_intervals(start, stop, baseline, project_id) as (
          select
            start start,
            lead(start, 1) over(partition by project_id order by start),
            baseline,
            project_id
          from bases
          where project_id = #{project}
        ),
        source_intervals(start, stop, baseline, project_id, source_id, real_issue_id, plan_issue_id) as (
          select
            start,
            stop,
            baseline,
            project_id,
            easy_baseline_sources.id source_id,
            easy_baseline_sources.source_id real_issue_id,
            easy_baseline_sources.destination_id plan_issue_id
          from base_intervals
          inner join easy_baseline_sources on easy_baseline_sources.baseline_id = baseline
        ),
        source_days(start, stop, day, baseline, project_id, source_id, real_issue_id, plan_issue_id) as (
          select
            cast(source_intervals.start as date) start,
            cast(source_intervals.stop as date) stop,
            dates.cdate day,
            source_intervals.baseline baseline,
            source_intervals.project_id project_id,
            source_intervals.source_id source_id,
            source_intervals.real_issue_id real_issue_id,
            source_intervals.plan_issue_id plan_issue_id
          from source_intervals
          inner join dates
            on dates.cdate >= cast(source_intervals.start as date)
              and (
                source_intervals.stop is null
                or dates.cdate <= cast(source_intervals.stop as date)
              )
        ),
        status_intervals(start, stop, issue_id, project_id, status_id) as (
          select
            journals.created_on start,
            lead(journals.created_on, 1) over (partition by journals.journalized_id order by journals.created_on) stop,
            journals.journalized_id issue_id,
            issues.project_id project_id,
            cast(journal_details.value as integer) status_id
          from journal_details
          inner join journals on journals.id = journal_details.journal_id
          inner join issues on journals.journalized_type = 'Issue'
            and issues.id = journals.journalized_id
          where journal_details.property = 'attr' and journal_details.prop_key = 'status_id'
        ),
        status_issues(start, stop, issue_id, project_id, status_id) as (
          select
            start_date start,
            due_date stop,
            id issue_id,
            project_id project_id,
            status_id status_id
          from issues
          where id not in (select distinct issue_id from status_intervals)
        ),
        status_days(day, start, stop, issue_id, status_id) as (
          select
            dates.cdate day,
            cast(status_intervals.start as date) start,
            coalesce(cast(status_intervals.stop as date), (select date_stop from params)) stop,
            status_intervals.issue_id issue_id,
            status_intervals.status_id status_id
          from dates
          inner join status_intervals
            on
              dates.cdate >= cast(status_intervals.start as date)
              and status_intervals.status_id != 1
              and (
                status_intervals.stop is null
                or dates.cdate <= cast(status_intervals.stop as date)
                or status_intervals.status_id in (select id from closed_statuses)
              )
          union
          select
            dates.cdate day,
            cast(status_issues.start as date) start,
            coalesce(cast(status_issues.stop as date), (select date_stop from params)) stop,
            status_issues.issue_id issue_id,
            status_issues.status_id status_id
          from dates
          inner join status_issues
            on cast(status_issues.start as date) >= dates.cdate
            and status_issues.status_id != 1
            and (
              status_issues.status_id in (select id from closed_statuses)
              or status_issues.stop is null
              or dates.cdate <= cast(status_issues.stop as date)
            )
        ),
        any_days(day, start, stop, issue_id, status_id) as (
          select
            dates.cdate day,
            cast(status_intervals.start as date) start,
            coalesce(cast(status_intervals.stop as date), (select date_stop from params)) stop,
            status_intervals.issue_id issue_id,
            status_intervals.status_id status_id
          from dates
          inner join status_intervals
            on
              dates.cdate >= cast(status_intervals.start as date)
              and (
                status_intervals.stop is null
                or dates.cdate <= cast(status_intervals.stop as date)
                or status_intervals.status_id in (select id from closed_statuses)
              )
          union
          select
            dates.cdate day,
            cast(status_issues.start as date) start,
            coalesce(cast(status_issues.stop as date), (select date_stop from params)) stop,
            status_issues.issue_id issue_id,
            status_issues.status_id status_id
          from dates
          inner join status_issues
            on cast(status_issues.start as date) >= dates.cdate
            and (
              status_issues.status_id in (select id from closed_statuses)
              or status_issues.stop is null
              or dates.cdate <= cast(status_issues.stop as date)
            )
        ),
        source_status_days(
          start, stop, day, status_id, project_id, baseline, source_id, real_issue_id,
          plan_issue_id, plan_start_date, plan_due_date, work
        ) as (
          select
            status_days.start,
            status_days.stop,
            status_days.day,
            status_days.status_id,
            source_days.project_id,
            source_days.baseline,
            source_days.source_id,
            source_days.real_issue_id,
            source_days.plan_issue_id,
            cast(issues.start_date as date) plan_start_date,
            cast(issues.due_date as date) plan_due_date,
            1 work
          from status_days
          inner join source_days
            on
              status_days.issue_id = source_days.real_issue_id
              and status_days.day = source_days.day
          inner join issues
            on issues.id = source_days.plan_issue_id
          where status_days.day >= cast(issues.start_date as date)
          and (
            issues.due_date is null
            or status_days.day <= cast(issues.due_date as date)
          )
        ),
        result(
          start, stop, day, status_id, project_id, baseline, source_id, real_issue_id,
          plan_issue_id, plan_start_date, plan_due_date, work
        ) as (
          select
            source_status_days.start,
            source_status_days.stop,
            source_status_days.day,
            source_status_days.status_id,
            source_status_days.project_id,
            source_status_days.baseline,
            source_status_days.source_id,
            source_status_days.real_issue_id,
            source_status_days.plan_issue_id,
            source_status_days.plan_start_date plan_start_date,
            source_status_days.plan_due_date plan_due_date,
            source_status_days.work work
          from source_status_days
          union
          select
            any_days.start,
            any_days.stop,
            any_days.day,
            any_days.status_id,
            source_days.project_id,
            source_days.baseline,
            source_days.source_id,
            source_days.real_issue_id,
            source_days.plan_issue_id,
            cast(issues.start_date as date) plan_start_date,
            cast(issues.due_date as date) plan_due_date,
            0 work
          from any_days
          inner join source_days
            on
              any_days.issue_id = source_days.real_issue_id
              and any_days.day = source_days.day
          inner join issues
            on issues.id = source_days.plan_issue_id
          where any_days.day >= cast(issues.start_date as date)
          and (
            issues.due_date is null
            or any_days.day <= cast(issues.due_date as date)
          )
          and not exists (
            select * from source_status_days
            where
              any_days.day = source_status_days.day
              and source_days.source_id = source_status_days.source_id
              and any_days.status_id = source_status_days.status_id
          )
        )
        select * from result
      SQL
    end
  end
end
