# frozen_string_literal: true

require_relative "../../../rules_find"

module RestmeRails
  module Core
    module Scope
      module Field
        # Handles nested association preloading for scoped queries.
        #
        # Responsibilities:
        #
        # - Validates requested nested associations against NESTED_SELECTABLE_FIELDS
        # - Applies preload for allowed associations
        # - Parses field selection per association (string or hash format)
        # - Exposes valid_nested_fields_select for SelectAttachments serialization
        # - Exposes unallowed selections for error aggregation in Rules
        #
        # Query params:
        #
        #   ?nested_fields_select=profile,company
        #   ?nested_fields_select[profile]=id,name&nested_fields_select[company]=id
        #
        # Convention — optional class per model:
        #
        #   "#{ModelName}Restme::Field::Rules"
        #
        # May define:
        #
        #   NESTED_SELECTABLE_FIELDS = { profile: {}, company: {} }
        #
        class SelectNestedFields
          # @param context [RestmeRails::Context]
          def initialize(context:)
            @context = context
          end

          # Applies preload for valid nested associations.
          #
          # @param scope [ActiveRecord::Relation]
          # @return [ActiveRecord::Relation]
          def process(scope)
            return scope unless valid_nested_fields_select

            scope.preload(valid_nested_fields_select.keys)
          end

          # Validated nested associations with optional field selection.
          #
          # Keys are allowed association names; values are either:
          #   nil           → include all fields
          #   [:id, :name]  → include only these fields
          #
          # Examples:
          #   "profile,company"           → { profile: nil, company: nil }
          #   { "profile" => "id,name" }  → { profile: [:id, :name] }
          #
          # @return [Hash, nil]
          def valid_nested_fields_select
            @valid_nested_fields_select ||= nested_fields_parsed
                                            .select { |assoc, _| nested_selectable_fields_keys.key?(assoc) }
                                            .presence
          end

          # Associations requested but not in NESTED_SELECTABLE_FIELDS.
          # Used by Rules to build a single combined error.
          #
          # @return [Array<Symbol>]
          def unallowed
            return [] if nested_fields_select.blank?

            nested_fields_parsed.keys - (valid_nested_fields_select&.keys || [])
          end

          private

          attr_reader :context

          # Parses nested_fields_select into a normalized Hash.
          #
          # Supports:
          #   String: "profile,company"          → { profile: nil, company: nil }
          #   Hash:   { "profile" => "id,name" } → { profile: [:id, :name] }
          #
          # @return [Hash]
          def nested_fields_parsed
            return {} if nested_fields_select.blank?

            return parse_hash_nested_fields if nested_fields_select.respond_to?(:each_pair)

            parse_string_nested_fields
          end

          def parse_hash_nested_fields
            nested_fields_select.to_h do |assoc, fields_str|
              [assoc.to_sym, fields_str.split(",").map { |f| f.strip.to_sym }.presence]
            end
          end

          def parse_string_nested_fields
            nested_fields_select.to_s.split(",").to_h { |assoc| [assoc.strip.to_sym, nil] }
          end

          # Allowed nested associations declared in the Field Rules class.
          #
          # Falls back to an empty hash when no NESTED_SELECTABLE_FIELDS is defined.
          #
          # @return [Hash]
          def nested_selectable_fields_keys
            @nested_selectable_fields_keys ||=
              if field_class_rules&.const_defined?(:NESTED_SELECTABLE_FIELDS)
                field_class_rules::NESTED_SELECTABLE_FIELDS
              else
                {}
              end
          end

          # Query param: nested_fields_select
          #
          # @return [String, Hash, nil]
          def nested_fields_select
            @nested_fields_select ||= context.query_params[:nested_fields_select]
          end

          # Dynamically resolves the Field Rules class for the model.
          #
          # @return [Class, nil]
          def field_class_rules
            @field_class_rules ||= RestmeRails::RulesFind.new(
              klass: context.model_class,
              rule_context: "Field"
            ).rule_class
          end
        end
      end
    end
  end
end
