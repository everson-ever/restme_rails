# frozen_string_literal: true

require_relative "../shared/restme_current_user_roles"
require_relative "../shared/current_model"

module RestmeRails
  module Authorize
    # Provides a simple role-based authorization layer.
    #
    # Authorization strategy:
    #
    # 1. If there is no current user, access is allowed.
    # 2. If the action is allowed for at least one of the user's roles, access is allowed.
    # 3. Otherwise, a forbidden error is returned.
    #
    # Expected convention:
    #
    # A Rules class may exist following the pattern:
    #   "#{ControllerName}Restme::Authorize::Rules"
    #
    # The Rules class may define:
    #
    #   ALLOWED_ROLES_ACTIONS = {
    #     index:  [:admin, :manager],
    #     create: [:admin]
    #   }
    #
    # Each action maps to an array of allowed roles.
    #
    module Rules
      include ::RestmeRails::Shared::CurrentModel
      include ::RestmeRails::Shared::RestmeCurrentUserRoles

      # Determines whether the current user is authorized.
      #
      # Returns true if:
      # - There is no current user
      # - The user has at least one allowed role for the action
      #
      # Otherwise:
      # - Registers authorization errors
      # - Returns false
      #
      # @return [Boolean]
      def user_authorized?
        return true if restme_current_user.blank? || authorize?

        authorize_errors
        false
      end

      # Checks whether the current user's roles
      # intersect with allowed roles for the action.
      #
      # @return [Boolean]
      def authorize?
        allowed_roles_actions&.intersect?(restme_current_user_roles)
      end

      # Registers authorization error response.
      #
      # Sets:
      # - Error message
      # - HTTP status :forbidden
      #
      # @return [void]
      def authorize_errors
        restme_scope_errors(
          {
            message: "Action not allowed",
            body: {}
          }
        )

        restme_scope_status(:forbidden)
      end

      # Returns allowed roles for the current action.
      #
      # Reads from:
      #   ALLOWED_ROLES_ACTIONS[action_name]
      #
      # If no Rules class or constant exists, returns an empty array.
      #
      # @return [Array<Symbol>]
      def allowed_roles_actions
        return [] unless authorize_rules_class&.const_defined?(:ALLOWED_ROLES_ACTIONS)

        authorize_rules_class::ALLOWED_ROLES_ACTIONS[action_name.to_sym] || []
      end

      # Resolves the authorization Rules class dynamically.
      #
      # Naming convention:
      #   "#{ControllerName}Restme::Authorize::Rules"
      #
      # Uses safe_constantize to avoid raising errors.
      #
      # @return [Class, nil]
      def authorize_rules_class
        "#{klass.name}Rules::Authorize::Rules"
          .safe_constantize
      end
    end
  end
end
