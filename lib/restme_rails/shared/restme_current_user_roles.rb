# frozen_string_literal: true

module RestmeRails
  module Shared
    # Provides normalized access to the current user's roles.
    #
    # All roles are returned as an Array of symbols,
    # regardless of how they are stored (String, Symbol, etc).
    module RestmeCurrentUserRoles
      # Returns the current user's roles normalized as symbols.
      #
      # Examples:
      #   "admin"      -> [:admin]
      #   ["admin"]    -> [:admin]
      #   [:admin]     -> [:admin]
      #   nil          -> []
      #
      # @return [Array<Symbol>]
      def restme_current_user_roles
        Array.wrap(user_roles).map do |role|
          # Ensures every role is converted to a Symbol
          role.respond_to?(:to_sym) ? role.to_sym : role.to_s.to_sym
        end
      end

      # Returns the raw roles from the configured user role field.
      #
      # The field name is defined in:
      #   RestmeRails::Configuration.user_role_field
      #
      # Example:
      #   :role
      #   :roles
      #
      # Memoized for performance.
      #
      # @return [Object, nil]
      def user_roles
        @user_roles ||= restme_current_user&.try(
          ::RestmeRails::Configuration.user_role_field
        )
      end
    end
  end
end
