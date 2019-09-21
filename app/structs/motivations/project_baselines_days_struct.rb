module Motivations
  class ProjectBaselinesDaysStruct < Motivations::Base
    property :day, transform_with: ->(val) { val.to_date rescue Date.parse(val) }
    property :project, transform_with: ->(val) { val.to_i }
    property :baseline, transform_with: ->(val) { val.to_i }
  end
end
