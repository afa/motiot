require 'dry/validation/compat/form'
require 'reform/form/dry'
class BaseForm < Reform::Form
  include Reform::Form::ActiveModel
  include Reform::Form::ActiveModel::FormBuilderMethods
  feature Reform::Form::Dry
end
