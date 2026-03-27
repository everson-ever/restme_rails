# frozen_string_literal: true

require_relative "../../../rules_find"

module RestmeRails
  module Core
    module Scope
      module Field
        # Handles model attribute selection for scoped queries.
        #
        # Responsibilities:
        #
        # - Applies SELECT clause based on requested and allowed fields
        # - Merges whitelist (MODEL_FIELDS_SELECT) with client selection
        # - Enforces blacklist (UNALLOWED_MODEL_FIELDS_SELECT)
        # - Exposes unallowed selections for error aggregation in Rules
        #
        # Query param:
        #
        #   ?fields_select=id,name,email
        #
        # Convention — optional class per model:
        #
        #   "#{ModelName}Restme::Field::Rules"
        #
        # May define:
        #
        #   MODEL_FIELDS_SELECT          = [:id, :name]
        #   UNALLOWED_MODEL_FIELDS_SELECT = [:internal_token]
        #
        class SelectFields
          # @param context [RestmeRails::Context]
          def initialize(context:)
            @context = context
          end

          # Applies SELECT clause to the scope.
          #
          # @param scope [ActiveRecord::Relation]
          # @return [ActiveRecord::Relation]
          def process(scope)
            scope.select(model_fields_select)
          end

          # Fields that were requested but are not allowed.
          # Used by Rules to build a single combined error.
          #
          # @return [Array<Symbol>]
          def unallowed
            return [] if fields_select.blank?

            fields_select.split(",").map(&:to_sym) - model_attributes.map(&:to_sym)
          end

          # Final list of model fields to apply in SELECT.
          #
          # Merges whitelist with client selection, falling back to all
          # allowed attributes when no explicit selection is made.
          #
          # @return [Array<String>]
          def model_fields_select
            @model_fields_select ||= select_selected_fields.presence || model_attributes
          end

          private

          attr_reader :context

          # Merges whitelist + client selection.
          #
          # @return [Array<String>]
          def select_selected_fields
            @select_selected_fields ||= defined_fields_select |
                                        fields_select.split(",").map(&:to_s)
          end

          # All model column names excluding blacklisted fields.
          #
          # @return [Array<String>]
          def model_attributes
            @model_attributes ||= context.model_class.attribute_names -
                                  unallowed_model_fields_select
          end

          # Fields whitelisted via MODEL_FIELDS_SELECT.
          #
          # @return [Array<String>]
          def defined_fields_select
            return [] unless field_class_rules&.const_defined?(:MODEL_FIELDS_SELECT)

            (field_class_rules::MODEL_FIELDS_SELECT || []).map(&:to_s)
          end

          # Fields blacklisted via UNALLOWED_MODEL_FIELDS_SELECT.
          #
          # @return [Array<String>]
          def unallowed_model_fields_select
            return [] unless field_class_rules&.const_defined?(:UNALLOWED_MODEL_FIELDS_SELECT)

            (field_class_rules::UNALLOWED_MODEL_FIELDS_SELECT || []).map(&:to_s)
          end

          # Query param: fields_select
          #
          # @return [String]
          def fields_select
            @fields_select ||= context.query_params[:fields_select] || ""
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
