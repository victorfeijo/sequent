require 'active_record'
module Sequent
  module Core
    class CommandRecord < ActiveRecord::Base

      self.table_name = "command_records"

      validates_presence_of :command_type, :command_json

      def command
        args = JSON.parse(command_json)
        Class.const_get(command_type.to_sym).deserialize_from_json(args)
      end

      def command=(command)
        self.created_at = command.created_at
        self.aggregate_id = command.aggregate_id if command.respond_to? :aggregate_id
        self.organization_id = command.organization_id if command.respond_to? :organization_id
        self.user_id = command.user_id if command.respond_to? :user_id
        self.command_type = command.class.name
        self.command_json = command.to_json.to_s
      end
    end
  end
end
