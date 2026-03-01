# frozen_string_literal: true

require_relative "attachable"
require_relative "../../../rules_find"

module RestmeRails
  module Core
    module Scope
      module Field
        # Handles field selection logic for scoped queries.
        #
        # Responsibilities:
        #
        # - Filters model attributes based on:
        #     - fields_select
        #     - nested_fields_select
        #     - MODEL_FIELDS_SELECT (whitelist)
        #     - UNALLOWED_MODEL_FIELDS_SELECT (blacklist)
        #
        # - Validates unallowed field selections
        # - Applies nested preloads
        # - Delegates attachment handling to Attachable
        #
        # Query params supported:
        #
        #   ?fields_select=id,name,email
        #   ?nested_fields_select=profile,company
        #   ?attachment_fields_select=avatar
        #
        # Expected convention:
        #
        # A Field Rules class may exist following:
        #
        #   "#{ModelName}Restme::Field::Rules"
        #
        # It may define:
        #
        #   MODEL_FIELDS_SELECT = [:id, :name]
        #   UNALLOWED_MODEL_FIELDS_SELECT = [:internal_token]
        #   NESTED_SELECTABLE_FIELDS = { profile: {}, company: {} }
        #
        class Rules
          attr_reader :context, :scope_error_instance, :attachable_instance

          # @param context [RestmeRails::Context]
          # @param scope_error_instance [ScopeError]
          def initialize(context:, scope_error_instance:)
            @context = context
            @scope_error_instance = scope_error_instance

            @attachable_instance = RestmeRails::Core::Scope::Field::Attachable.new(
              context: context,
              attachment_fields_select: attachment_fields_select,
              valid_nested_fields_select: valid_nested_fields_select,
              scope_error_instance: scope_error_instance
            )
          end

          # Applies field selection rules to a given scope.
          #
          # Flow:
          # 1. Selects allowed model attributes
          # 2. Applies nested preloads
          # 3. Applies attachment serialization
          #
          # @param user_scope [ActiveRecord::Relation]
          # @return [ActiveRecord::Relation, Array<Hash>]
          def fieldable_scope(user_scope)
            return user_scope unless select_any_field?

            scoped = user_scope

            scoped = user_scope.select(model_fields_select) if model_fields_select
            scoped = select_nested_scope(scoped) if valid_nested_fields_select

            attachable_instance.insert_attachments(scoped)
          rescue ActiveModel::MissingAttributeError => e
            add_scope_error(e)
          end

          # Registers error if client selects invalid fields.
          #
          # @return [Boolean, nil]
          def unallowed_select_fields_errors
            return if unallowed_fields_selected.blank?

            scope_error_instance.add_error(
              body: unallowed_fields_selected,
              message: "Selected not allowed fields"
            )

            scope_error_instance.add_status(:bad_request)

            true
          end

          # Delegates attachment validation to Attachable.
          #
          # @return [void]
          def unallowed_attachment_fields_errors
            attachable_instance.unallowed_attachment_fields_errors
          end

          private

          # Registers ActiveModel::MissingAttributeError
          #
          # @return [void]
          def add_scope_error(message)
            scope_error_instance.add_error(
              body: model_fields_select,
              message: message
            )

            scope_error_instance.add_status(:bad_request)
          end

          # Applies nested association preloads.
          #
          # @param scoped [ActiveRecord::Relation]
          # @return [ActiveRecord::Relation]
          def select_nested_scope(scoped)
            scoped.preload(valid_nested_fields_select)
          end

          # Determines whether any field selection param exists.
          #
          # @return [Boolean]
          def select_any_field?
            defined_fields_select ||
              fields_select ||
              nested_fields_select ||
              attachment_fields_select
          end

          # Final model fields to select.
          #
          # If client specifies fields_select, merge with defined whitelist.
          # Otherwise fallback to all allowed attributes.
          #
          # @return [Array<String>]
          def model_fields_select
            @model_fields_select ||= select_selected_fields.presence || model_attributes
          end

          # Merges whitelist + client selection.
          #
          # @return [Array<String>]
          def select_selected_fields
            @select_selected_fields ||= defined_fields_select |
                                        fields_select.split(",").map(&:to_s)
          end

          # Returns allowed model attributes excluding blacklisted ones.
          #
          # @return [Array<String>]
          def model_attributes
            @model_attributes ||= context.model_class.attribute_names -
                                  unallowed_model_fields_select
          end

          # Fields explicitly defined via MODEL_FIELDS_SELECT.
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

          # Valid nested associations based on whitelist.
          #
          # @return [Array<Symbol>, nil]
          def valid_nested_fields_select
            @valid_nested_fields_select ||= nested_fields_select
                                            &.split(",")
                                            &.select { |field| nested_selectable_fields_keys.key?(field.to_sym) }
                                            &.map(&:to_sym)
          end

          # Aggregates all invalid selections.
          #
          # @return [Array<Symbol>]
          def unallowed_fields_selected
            unallowed_nested_fields_select + unallowed_fields_select
          end

          # Nested associations not allowed.
          #
          # @return [Array<Symbol>]
          def unallowed_nested_fields_select
            return [] if nested_fields_select.blank?

            nested_fields_select.split(",").map(&:to_sym) -
              valid_nested_fields_select
          end

          # Model attributes not allowed.
          #
          # @return [Array<Symbol>]
          def unallowed_fields_select
            return [] if fields_select.blank?

            fields_select.split(",").map(&:to_sym) -
              model_attributes.map(&:to_sym)
          end

          # Query param: fields_select
          #
          # @return [String]
          def fields_select
            @fields_select ||= context.query_params[:fields_select] || ""
          end

          # Query param: nested_fields_select
          #
          # @return [String, nil]
          def nested_fields_select
            @nested_fields_select ||= context.query_params[:nested_fields_select]
          end

          # Query param: attachment_fields_select
          #
          # @return [Array<Symbol>, nil]
          def attachment_fields_select
            @attachment_fields_select ||= context.query_params[:attachment_fields_select]
                                                 &.split(",")
                                                 &.map(&:to_sym)
          end

          # Returns allowed nested associations defined in rules.
          #
          # @return [Hash, nil]
          def nested_selectable_fields_keys
            @nested_selectable_fields_keys ||= if field_class_rules&.const_defined?(:NESTED_SELECTABLE_FIELDS)
                                                 field_class_rules::NESTED_SELECTABLE_FIELDS
                                               end
          end

          # Dynamically resolves Field Rules class.
          #
          # Uses:
          #   RestmeRails::RulesFind
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
