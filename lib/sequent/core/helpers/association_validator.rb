require 'active_model'
module Sequent
  module Core
    module Helpers
      class Sequent::Core::Helpers::AssociationValidator < ActiveModel::Validator

        def validate(record)
          associations = options[:associations]
          associations = [associations] unless associations.instance_of?(Array)
          associations.each do |association|
            next unless association # since ruby 2.0...?
            value = record.instance_variable_get("@#{association.to_s}")
            if value && !value.kind_of?(Array) && record.respond_to?(:attributes) && !value.kind_of?(record.attributes[association])
              record.errors[association] = "is not of type #{record.attributes[association]}"
            elsif value && value.kind_of?(Array)
              record.errors[association] = "is invalid" if value.any? { |v| not v.valid? }
            else
              record.errors[association] = "is invalid" if value && value.invalid?

            end
          end
        end
      end
    end
  end
end
