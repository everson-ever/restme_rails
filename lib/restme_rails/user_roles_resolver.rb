# frozen_string_literal: true

module RestmeRails
  # Responsible for resolving and normalizing roles from the current user.
  #
  # This class extracts user roles using a configurable attribute
  # defined in:
  #
  #   RestmeRails::Configuration.user_role_field
  #
  # It guarantees that the returned roles are always normalized
  # as an Array of Symbols.
  #
  # Example:
  #
  #   # If user.roles returns:
  #   ["admin", "editor"]
  #
  #   resolver.current_user_roles
  #   # => [:admin, :editor]
  #
  #   # If user.role returns:
  #   "admin"
  #
  #   resolver.current_user_roles
  #   # => [:admin]
  #
  #   # If user has no roles:
  #   resolver.current_user_roles
  #   # => []
  #
  # @note Relies on ActiveSupport's Array.wrap.
  #
  class UserRolesResolver
    # @return [Object, nil]
    #   The currently authenticated user.
    attr_reader :current_user

    # @param current_user [Object, nil]
    #   The user object from which roles will be extracted.
    def initialize(current_user:)
      @current_user = current_user
    end

    # Returns normalized user roles as symbols.
    #
    # Behavior:
    # - Fetches role attribute using configured field
    # - Wraps result in an Array
    # - Converts each role to Symbol
    #
    # @return [Array<Symbol>]
    def current_user_roles
      Array(user_roles)
        .compact
        .map { |role| role.to_s.strip.downcase.to_sym }
        .uniq
    end

    private

    # Extracts roles from current_user using the configured role field.
    #
    # Example configuration:
    #
    #   RestmeRails.configure do |config|
    #     config.user_role_field = :roles
    #   end
    #
    # @return [Object, nil]
    def user_roles
      @user_roles ||= begin
        user_role_key = ::RestmeRails::Configuration.user_role_field

        if current_user.respond_to?(user_role_key)
          current_user.public_send(
            user_role_key
          )
        end
      end
    end
  end
end
