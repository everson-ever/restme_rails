# frozen_string_literal: true

require_relative "select_fields"
require_relative "select_nested_fields"
require_relative "select_attachments"

module RestmeRails
  module Core
    module Scope
      module Field
        # Orchestrates field selection for scoped queries.
        #
        # Delegates each concern to a focused class:
        #
        #   SelectFields        → model attribute selection (fields_select)
        #   SelectNestedFields  → association preloading (nested_fields_select)
        #   SelectAttachments   → attachment URL injection (attachment_fields_select)
        #
        # Query params supported:
        #
        #   ?fields_select=id,name,email
        #   ?nested_fields_select=profile,company
        #   ?nested_fields_select[profile]=id,name&nested_fields_select[company]=id
        #   ?attachment_fields_select=avatar
        #
        class Rules
          attr_reader :context, :scope_error_instance

          # @param context [RestmeRails::Context]
          # @param scope_error_instance [ScopeError]
          def initialize(context:, scope_error_instance:)
            @context = context
            @scope_error_instance = scope_error_instance
          end

          # Applies field selection pipeline to the given scope.
          #
          # Flow:
          # 1. Applies SELECT clause for model attributes
          # 2. Preloads nested associations
          # 3. Serializes to JSON with attachment URLs injected
          #
          # @param user_scope [ActiveRecord::Relation]
          # @return [Array<Hash>]
          def process(user_scope)
            scoped = select_fields.process(user_scope)
            scoped = select_nested_fields.process(scoped)
            select_attachments.process(scoped)
          rescue ActiveModel::MissingAttributeError => e
            raise RestmeRails::MissingAttributeError, e.message
          end

          # Validates field selections and registers errors on scope_error_instance.
          #
          # @return [Boolean, nil]
          def errors
            unallowed_select_fields_errors || select_attachments.errors
          end

          private

          # Combines unallowed model fields and nested associations into a
          # single error entry to preserve the original error format.
          #
          # @return [Boolean, nil]
          def unallowed_select_fields_errors
            unallowed = select_nested_fields.unallowed + select_fields.unallowed
            return if unallowed.blank?

            scope_error_instance.add_error(
              body: unallowed,
              message: "Selected not allowed fields"
            )

            scope_error_instance.add_status(:bad_request)

            true
          end

          def select_fields
            @select_fields ||= SelectFields.new(context: context)
          end

          def select_nested_fields
            @select_nested_fields ||= SelectNestedFields.new(context: context)
          end

          def select_attachments
            @select_attachments ||= SelectAttachments.new(
              context: context,
              scope_error_instance: scope_error_instance,
              valid_nested_fields_select: select_nested_fields.valid_nested_fields_select
            )
          end
        end
      end
    end
  end
end
