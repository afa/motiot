module Gantt
  module Utility
    class ExportToXlsx
      include Dry::Transaction

      step :run

      private

      def run(user:, amount:, date_from:, date_to:)
        data_result = Gantt::Baseline::MotivationGenerator.new.call(
          user: user,
          amount: amount,
          date_range: date_from..date_to,
          requester: User.current
        )
        data = data_result.value!
        projects ||= data.values.flat_map(&:keys).compact.uniq.map { |id| Project.find(id) }
        daily_pay = amount.to_f / (date_from..date_to).to_a.size
        # projects = (date_from..date_to)
        #   .flat_map { |day| data.dig(day, :projects) }
        #   .compact
        #   .uniq
        #   .map { |id| Project.find(id) }
        book = RubyXL::Workbook.new
        sheet = book.worksheets[0]
        sheet ||= book.add_worksheet
        sheet.sheet_name = "Motivation_#{date_from.to_s(:db)}-#{date_to.to_s(:db)}"
        sheet.add_cell(
          0,
          0,
          "#{I18n.t('easy_gantt.create_motivation_report.motivation.for')} #{user.name} " \
          "#{I18n.t('easy_gantt.create_motivation_report.motivation.amount')} #{amount} " \
          "#{I18n.t('easy_gantt.create_motivation_report.motivation.from')} #{I18n.l(date_from)} " \
          "#{I18n.t('easy_gantt.create_motivation_report.motivation.to')} #{I18n.l(date_to)}"
        )
        sheet.merge_cells(0, 0, 0, 10)
        sheet.add_cell(2, 0, I18n.t('easy_gantt.create_motivation_report.motivation.head_projects'))
        sheet.change_column_width(0, 21)
        (date_from..date_to).each_with_index do |date, idx|
          sheet.change_column_width(1 + idx, 10)
          cell = sheet.add_cell(2, idx + 1)
          cell.set_number_format('dd-mm-yyyy')
          cell.change_contents(date)
        end
        projects.each_with_index do |project, prj_idx|
          sheet.add_cell(3 + prj_idx, 0, project.name)
          (date_from..date_to).each_with_index do |date, idx|
            pcount = data[date]&.values&.count { |item| !item.nil? }.to_f
            if pcount.to_f == 0.0
              sheet.add_cell(3 + prj_idx, 1 + idx, 0.0)
            elsif data.dig(date, project.id)
              sheet.add_cell(
                3 + prj_idx,
                1 + idx,
                format('%.02f', daily_pay.to_f / pcount.to_f)
              )
            else
              sheet.add_cell(3 + prj_idx, 1 + idx, 0.0)
            end
          end
        end
        total = 0.0
        sheet.add_cell(3 + projects.size, 0, I18n.t('easy_gantt.create_motivation_report.motivation.total'))
        (date_from..date_to).each_with_index do |date, idx|
          pcount = data[date]&.values&.count { |item| !item.nil? }.to_f
          pactive = data[date]&.values&.count { |item| item }.to_f
          if pcount.to_f == 0.0
            sheet.add_cell(3 + projects.size, 1 + idx, 0.0)
          else
            value = daily_pay.to_f * pactive.to_f / pcount.to_f
            total += value
            sheet.add_cell(3 + projects.size, 1 + idx, value.round(2))
          end
        end
        sheet.add_cell(4 + projects.size, 0, I18n.t('easy_gantt.create_motivation_report.motivation.for_range'))
        sheet.add_cell(4 + projects.size, 1, total.round(2))
        Success(output(book))
      end

      def output(book)
        book.worksheets.each { |ws| ws.sheet_name = ws.sheet_name.tr('/\*[]:?', ' ') }
        book.stream.string
      end
    end
  end
end
