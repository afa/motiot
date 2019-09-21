module Gantt
  module Utility
    class FormatColumn
      include Dry::Transaction

      STATUS_FORMATS = {
        Project::STATUS_ACTIVE => ::I18n.t(:project_status_active),
        Project::STATUS_CLOSED => ::I18n.t(:project_status_closed),
        Project::STATUS_ARCHIVED => ::I18n.t(:project_status_archived),
        Project::STATUS_PLANNED => ::I18n.t(:project_status_planned)
      }.freeze

      step :format_column

      private

      def format_column(entity:, column:, value:)
        return Success(format_project_status(value)) if entity.is_a?(Project) && column.name == :status

        return Success(format_date(value)) if value.is_a? Date

        return Success(format_float(value)) if float_point?(value)

        Success(value.to_s)
      end

      def format_project_status(value)
        STATUS_FORMATS[value.to_i] || ''
      end

      def format_date(value)
        options = {}
        options[:format] = Setting.date_format if Setting.date_format.present?
        ::I18n.l(value.to_date, options)
      end

      def float_point?(value)
        value.is_a?(Float) || value.is_a?(BigDecimal)
      end

      def format_float(value)
        number_with_precision(value, locale: User.current.language.presence || ::I18n.locale).to_s
      end
    end
  end
end
