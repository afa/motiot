module Motivations
  class IssueStatusDaysStruct < Motivations::Base
    property :start, transform_with: ->(val) { val.to_date rescue Date.parse(val) rescue nil }
    property :stop, transform_with: ->(val) { val.to_date rescue Date.parse(val) rescue nil }
    property :day, transform_with: ->(val) { val.to_date rescue Date.parse(val) rescue nil }
    property :project_id, transform_with: ->(val) { val.to_i }
    property :baseline, transform_with: ->(val) { val.to_i }
    property :source_id, transform_with: ->(val) { val.to_i }
    property :status_id, transform_with: ->(val) { val.to_i }
    property :real_issue_id, transform_with: ->(val) { val.to_i }
    property :plan_issue_id, transform_with: ->(val) { val.to_i }
    property :plan_start_date, transform_with: ->(val) { val.to_date rescue Date.parse(val) rescue nil }
    property :plan_due_date, transform_with: ->(val) { val.to_date rescue Date.parse(val) rescue nil }
    property :work, transform_with: ->(val) { val.nil? ? val : val.zero? ? false : true }
  end
end
