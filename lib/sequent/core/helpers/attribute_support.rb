require 'active_support'
require_relative '../ext/ext'

module Sequent
  module Core
    module Helpers
      # Provides functionality for defining attributes with their types
      #
      # Since our Commands and ValueObjects are not backed by a database like e.g. rails
      # we can not infer their types. We need the types to be able to parse from and to json.
      # We could have stored te type information in the json, but we didn't.
      #
      # You typically do not need to include this module in your classes. If you extend from
      # Sequent::Core::ValueObject, Sequent::Core::Event or Sequent::Core::BaseCommand you will
      # get this functionality for free.
      #
      module AttributeSupport
        # module containing class methods to be added
        module ClassMethods

          def types
            @types ||= {}
            if @merged_types
              @merged_types
            else
              @merged_types = is_a?(Class) && superclass.respond_to?(:types) ? @types.merge(superclass.types) : @types
              included_modules.select { |m| m.include? Sequent::Core::Helpers::AttributeSupport }.each do |mod|
                @merged_types.merge!(mod.types)
              end
              @merged_types
            end
          end

          def type_for(name)
            @types.find { |k, _| k == name }.last
          end

          def attrs(args)
            @types ||= {}
            @types.merge!(args)
            @associations = []
            args.each do |attribute, type|
              attr_accessor attribute
              if included_modules.include?(Sequent::Core::Helpers::TypeConversionSupport) && type.respond_to?(:add_validations_for)
                type.add_validations_for(self, attribute)
              end

              if type.class == Sequent::Core::Helpers::ArrayWithType
                @associations << attribute
              elsif included_modules.include?(ActiveModel::Validations) &&
                type.included_modules.include?(Sequent::Core::Helpers::AttributeSupport)
                @associations << attribute
              end
            end
            if included_modules.include?(ActiveModel::Validations) && @associations.present?
              validates_with Sequent::Core::Helpers::AssociationValidator, associations: @associations
            end
            # Generate method that sets all defined attributes based on the attrs hash.
            class_eval <<EOS
              def update_all_attributes(attrs)
                super if defined?(super)
                #{@types.map { |attribute, _|
              "@#{attribute} = attrs[:#{attribute}]"
            }.join("\n            ")}
                self
              end
EOS

            class_eval <<EOS
               def update_all_attributes_from_json(attrs)
                 super if defined?(super)
                 #{@types.map { |attribute, type|
              "@#{attribute} = #{type}.deserialize_from_json(attrs['#{attribute}'])"
            }.join("\n           ")}
               end
EOS
          end

          #
          # Allows you to define something is an array of a type
          # Example:
          #
          #   attrs trainees: array(Person)
          #
          def array(type)
            ArrayWithType.new(type)
          end

          def deserialize_from_json(args)
            unless args.nil?
              obj = allocate()
              obj.update_all_attributes_from_json(args)
              obj
            end
          end


          def numeric?(object)
            true if Float(object) rescue false
          end

        end

        # extend host class with class methods when we're included
        def self.included(host_class)
          host_class.extend(ClassMethods)
        end


        # needed for active module JSON serialization
        def attributes
          self.class.types
        end

        def validation_errors(prefix = nil)
          result = errors.to_hash
          self.class.types.each do |field|
            value = self.instance_variable_get("@#{field[0]}")
            if value.respond_to? :validation_errors
              value.validation_errors.each { |k, v| result["#{field[0].to_s}_#{k.to_s}".to_sym] = v }
            end
          end
          prefix ? HashWithIndifferentAccess[result.map { |k, v| ["#{prefix}_#{k}", v] }] : result
        end

      end

      class ArrayWithType
        attr_accessor :item_type

        def parse_from_string(values)
          values.map do |item|
            if item.respond_to?(:parse_attrs_to_correct_types)
              item.parse_attrs_to_correct_types
            else
              item_type.parse_from_string(item)
            end
          end
        end

        def initialize(item_type)
          raise "needs a item_type" unless item_type
          @item_type = item_type
        end

        def deserialize_from_json(value)
          value.nil? ? nil : value.map { |item| item_type.deserialize_from_json(item) }
        end

        def to_s
          "Sequent::Core::Helpers::ArrayWithType.new(#{item_type})"
        end
      end

    end
  end
end


