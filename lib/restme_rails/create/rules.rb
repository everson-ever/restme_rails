# frozen_string_literal: true

require_relative "../shared/restme_current_user_roles"
require_relative "../shared/current_model"
require_relative "../shared/controller_params"

module RestmeRails
  module Create
    # Provides a standardized create flow with:
    #
    # - Automatic model instantiation
    # - Role-based scope validation
    # - Optional Rules class integration
    # - Error normalization
    #
    # Expected conventions:
    #
    # 1. A Rules class may exist following the pattern:
    #    "#{ControllerName}Restme::Create::RestmeRules"
    #
    # 2. The Rules class may define:
    #    RESTME_CREATE_ACTIONS_RULES = [:create]
    #
    # 3. Scope methods must follow this format:
    #    "#{action}_#{role}_scope?"
    #
    # Example:
    #   create_admin_scope?
    #   create_manager_scope?
    #
    module Rules
      include ::RestmeRails::Shared::ControllerParams
      include ::RestmeRails::Shared::CurrentModel
      include ::RestmeRails::Shared::RestmeCurrentUserRoles

      # Executes the create flow.
      #
      # Steps:
      # 1. Builds the model instance
      # 2. Injects current_user if supported
      # 3. Validates scope rules
      # 4. Persists the record
      # 5. Returns either:
      #    - The created instance
      #    - A normalized error hash
      #
      # @param restme_create_custom_params [Hash]
      #   Additional params merged into controller_params
      #
      # @return [ActiveRecord::Base, Hash]
      def restme_create(restme_create_custom_params: {})
        @restme_create ||= begin
          @restme_create_custom_params = restme_create_custom_params

          restme_create_set_current_user

          restme_create_instance.save unless restme_create_instance.persisted?

          restme_create_errors.presence || restme_create_instance
        end
      end

      # Returns the appropriate HTTP status symbol
      # based on whether errors exist.
      #
      # @return [Symbol]
      def restme_create_status
        restme_create_errors ? :unprocessable_content : :created
      end

      private

      # Assigns current_user to the model instance
      # if the model defines `current_user=`.
      def restme_create_set_current_user
        return unless restme_current_user
        return unless restme_create_instance.respond_to?(:current_user)

        restme_create_instance.current_user = restme_current_user
      end

      # Resolves error output depending on:
      # - Whether action is scoped
      # - Whether validation errors exist
      #
      # @return [Hash, nil]
      def restme_create_errors
        return unless restme_create_current_action
        return restme_create_unscoped_errors unless restme_create_scope?
        return if restme_create_instance.errors.blank?

        restme_create_active_record_errors
      end

      # Instantiates the model using:
      # - controller_params
      # - optional custom params
      #
      # Memoized.
      #
      # @return [ActiveRecord::Base]
      def restme_create_instance
        @restme_create_instance ||= begin
          params = controller_params
          params = params.merge(@restme_create_custom_params) if @restme_create_custom_params.present?

          klass.new(params)
        end
      end

      # Error returned when no scope rule allows the action.
      #
      # @return [Hash]
      def restme_create_unscoped_errors
        { errors: ["Unscoped"] }
      end

      # Validates role-based scope rules.
      #
      # If no current user exists, scope is considered allowed.
      #
      # It checks dynamically generated methods:
      #   "#{action}_#{role}_scope?"
      #
      # @return [Boolean]
      def restme_create_scope?
        return true unless restme_current_user

        restme_create_methods_scopes.any? do |method_scope|
          restme_create_rules_class_instance.respond_to?(method_scope) &&
            restme_create_rules_class_instance.public_send(method_scope)
        end
      end

      # Builds the list of possible scope methods
      # based on current action and user roles.
      #
      # Example:
      #   create_admin_scope?
      #   create_user_scope?
      #
      # @return [Array<String>]
      def restme_create_methods_scopes
        @restme_create_methods_scopes ||= restme_current_user_roles.map do |restme_role|
          "#{restme_create_current_action}_#{restme_role}_scope?"
        end
      end

      # Returns the current action only if it is declared
      # inside RESTME_CREATE_ACTIONS_RULES.
      #
      # @return [Symbol, nil]
      def restme_create_current_action
        return unless restme_create_rules_class&.const_defined?(:RESTME_CREATE_ACTIONS_RULES)

        restme_create_controller_current_action.presence_in(
          restme_create_rules_class::RESTME_CREATE_ACTIONS_RULES
        )
      end

      # Returns the controller action name as symbol.
      #
      # @return [Symbol]
      def restme_create_controller_current_action
        action_name.to_sym
      end

      # ActiveRecord error format for validation errors.
      #
      # @return [Hash]
      def restme_create_active_record_errors
        {
          errors: restme_create_instance.errors.messages
        }
      end

      # Instantiates the Rules class if it exists.
      #
      # Initialized with:
      #   (instance, current_user)
      #
      # @return [Object, nil]
      def restme_create_rules_class_instance
        @restme_create_rules_class_instance ||=
          restme_create_rules_class&.new(
            restme_create_instance,
            restme_current_user
          )
      end

      # Resolves the Rules class dynamically following
      # the naming convention:
      #
      #   "#{ControllerName}Restme::Create::RestmeRules"
      #
      # Uses safe_constantize to avoid raising errors.
      #
      # @return [Class, nil]
      def restme_create_rules_class
        @restme_create_rules_class ||=
          "#{klass.name}Rules::Create::Rules"
          .safe_constantize
      end
    end
  end
end
