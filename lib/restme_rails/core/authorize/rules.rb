# frozen_string_literal: true

require_relative "../../rules_find"

module RestmeRails
  module Core
    module Authorize
      # Core::Authorize::Rules
      #
      # Provides a lightweight role-based authorization layer.
      #
      # ------------------------------------------------------------
      # Authorization Strategy
      # ------------------------------------------------------------
      #
      # 1. If there is no current user → access is allowed.
      # 2. If the current user's roles intersect with allowed roles
      #    for the action → access is allowed.
      # 3. Otherwise → raises NotAuthorizedError.
      #
      # ------------------------------------------------------------
      # Expected Convention
      # ------------------------------------------------------------
      #
      # A rules class may exist following the naming convention:
      #
      #   "#{ModelName}Rules::Authorize::Rules"
      #
      # Example:
      #
      #   class ProductRules::Authorize::Rules
      #     ALLOWED_ROLES_ACTIONS = {
      #       index:  [:admin, :manager],
      #       create: [:admin]
      #     }
      #   end
      #
      # Each controller action maps to an array of allowed roles.
      #
      class Rules
        attr_reader :context

        # Raised when the user is not authorized
        class NotAuthorizedError < StandardError; end

        # @param context [RestmeRails::Context]
        def initialize(context:)
          @context = context
        end

        # Performs authorization check.
        #
        # @raise [NotAuthorizedError] if user is not authorized
        # @return [true] if authorized
        def authorize!
          return true if context.current_user.blank?
          return true if authorized?

          raise NotAuthorizedError, "Action not allowed"
        end

        private

        # Checks if user roles intersect allowed roles for action.
        #
        # @return [Boolean]
        def authorized?
          allowed_roles_for_action.intersect?(context.current_user_roles)
        end

        # Returns allowed roles for current action.
        #
        # If no rules class or constant exists, defaults to empty array.
        #
        # @return [Array<Symbol>]
        def allowed_roles_for_action
          return [] unless rules_class&.const_defined?(:ALLOWED_ROLES_ACTIONS)

          rules_class::ALLOWED_ROLES_ACTIONS[context.action_name] || []
        end

        # Dynamically resolves authorization rules class.
        #
        # Uses RestmeRails::RulesFind to follow naming convention.
        #
        # @return [Class, nil]
        def rules_class
          @rules_class ||= RestmeRails::RulesFind.new(
            klass: context.model_class,
            rule_context: "Authorize"
          ).rule_class
        end
      end
    end
  end
end
