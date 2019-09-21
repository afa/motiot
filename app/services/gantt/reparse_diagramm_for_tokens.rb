module Gantt
  class ReparseDiagrammForTokens
    include Dry::Transaction

    step :calc

    private

    def calc(text:)
      doc = Nokogiri::HTML.fragment(text)
      # doc.css('div.gantt_grid_superitem').each do |nd|
      doc.css('div.gantt_row.task-type').each do |nd|
        tid = nd.classes.select { |cl| cl =~ /\Atask_\d+/ }.first
        next unless tid

        id = tid.match(/\Atask_(\d+)/)[1]
        next unless id

        issue = Issue.includes(project: :tracker_setting).find_by(id: id)
        project = issue.project
        next unless issue

        setting = project.tracker_setting
        track = setting&.tracker_id
        next unless issue.tracker_id == track

        nd.css('div.gantt_cell.gantt_grid_body_subject').each do |md|
          style = mk_style(setting)
          md.children.last['style'] = "style=\"#{style}\""
        end
      end
      Success(doc.to_html)
    end

    def mk_style(setting)
      style = ''
      style += 'font-weight: bold;' if setting.bold
      style += 'font-style: italic;' if setting.italic
      style += 'text-decoration: underline;' if setting.underline
      style + "background-color: #{setting.color};"
    end
  end
end
