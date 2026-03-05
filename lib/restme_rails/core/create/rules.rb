# frozen_string_literal: true

require_relative "../../rules_find"

module RestmeRails
  module Core
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
      class Rules
        attr_reader :context

        def initialize(context:)
          @context = context
        end

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
        # @param custom_params [Hash]
        #   Additional params merged into controller_params
        #
        # @return [ActiveRecord::Base, Hash]
        def create(custom_params: {})
          @create ||= begin
            @custom_params = custom_params

            create_set_current_user

            create_instance.save unless create_instance.persisted?

            create_errors.presence || create_instance
          end
        end

        # Returns the appropriate HTTP status symbol
        # based on whether errors exist.
        #
        # @return [Symbol]
        def create_status
          create_errors ? :unprocessable_content : :created
        end

        private

        # Assigns current_user to the model instance
        # if the model defines `current_user=`.
        def create_set_current_user
          return unless context.current_user
          return unless create_instance.respond_to?(:current_user)

          create_instance.current_user = context.current_user
        end

        # Resolves error output depending on:
        # - Whether action is scoped
        # - Whether validation errors exist
        #
        # @return [Hash, nil]
        def create_errors
          return unless create_current_action
          return create_unscoped_errors unless create_scope?
          return if create_instance.errors.blank?

          create_active_record_errors
        end

        # Instantiates the model using:
        # - controller_params
        # - optional custom params
        #
        # Memoized.
        #
        # @return [ActiveRecord::Base]
        def create_instance
          @create_instance ||= begin
            params = context.controller_params_serialized
            params = params.merge(@custom_params) if @custom_params.present?

            context.model_class.new(params)
          end
        end

        # Error returned when no scope rule allows the action.
        #
        # @return [Hash]
        def create_unscoped_errors
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
        def create_scope?
          return true unless context.current_user

          create_methods_scopes.any? do |method_scope|
            create_rules_class_instance.respond_to?(method_scope) &&
              create_rules_class_instance.public_send(method_scope)
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
        def create_methods_scopes
          @create_methods_scopes ||= context.current_user_roles.map do |role|
            "#{create_current_action}_#{role}_scope?"
          end
        end

        # Returns the current action only if it is declared
        # inside RESTME_CREATE_ACTIONS_RULES.
        #
        # @return [Symbol, nil]
        def create_current_action
          return unless create_rules_class&.const_defined?(:RESTME_CREATE_ACTIONS_RULES)

          context.action_name.presence_in(
            create_rules_class::RESTME_CREATE_ACTIONS_RULES
          )
        end

        # ActiveRecord error format for validation errors.
        #
        # @return [Hash]
        def create_active_record_errors
          {
            errors: create_instance.errors.messages
          }
        end

        # Instantiates the Rules class if it exists.
        #
        # Initialized with:
        #   (instance, current_user)
        #
        # @return [Object, nil]
        def create_rules_class_instance
          @create_rules_class_instance ||=
            create_rules_class&.new(
              create_instance,
              context.current_user
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
        def create_rules_class
          @create_rules_class ||= RestmeRails::RulesFind.new(klass: context.model_class,
                                                             rule_context: "Create").rule_class
        end
      end
    end
  end
end
