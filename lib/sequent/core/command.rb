require_relative 'helpers/copyable'
require_relative 'helpers/attribute_support'
require_relative 'helpers/uuid_helper'
require_relative 'helpers/equal_support'
require_relative 'helpers/param_support'
require_relative 'helpers/mergable'

module Sequent
  module Core
    class BaseCommand
      include ActiveModel::Validations,
              ActiveModel::Serializers::JSON,
              Sequent::Core::Helpers::Copyable,
              Sequent::Core::Helpers::AttributeSupport,
              Sequent::Core::Helpers::UuidHelper,
              Sequent::Core::Helpers::EqualSupport,
              Sequent::Core::Helpers::ParamSupport,
              Sequent::Core::Helpers::Mergable

      attrs created_at: DateTime

      self.include_root_in_json = false

      def initialize(args = {})
        update_all_attributes args
        @created_at = DateTime.now
      end

    end

    module UpdateSequenceNumber
      extend ActiveSupport::Concern
      included do
        attrs sequence_number: Integer
        validates_presence_of :sequence_number
        validates_numericality_of :sequence_number, only_integer: true, allow_nil: true, allow_blank: true, greater_than: 0
      end
    end

    class Command < BaseCommand
      attrs aggregate_id: String, user_id: String

      def initialize(args = {})
        raise ArgumentError, "Missing aggregate_id" if args[:aggregate_id].nil?
        super
      end

    end

    class UpdateCommand < Command
      include UpdateSequenceNumber
    end

    class TenantCommand < Command
      attrs organization_id: String

      def initialize(args = {})
        raise ArgumentError, "Missing organization_id" if args[:organization_id].nil?
        super
      end
    end

    class UpdateTenantCommand < TenantCommand
      include UpdateSequenceNumber
    end

  end
end
