module Motivations
  class AuthorDaysStruct < Motivations::Base
    property :day, transform_with: ->(val) { val.to_date rescue Date.parse(val) }
    property :project, transform_with: ->(val) { val.to_i }
  end
end
