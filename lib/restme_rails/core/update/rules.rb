# frozen_string_literal: true

require_relative "../../rules_find"

module RestmeRails
  module Core
    module Update
      # Provides a standardized update flow with:
      #
      # - Record lookup by :id
      # - Attribute assignment
      # - Role-based scope validation
      # - Optional Rules class integration
      # - Error normalization
      #
      # Expected conventions:
      #
      # 1. A Rules class may exist following the pattern:
      #    "#{ControllerName}Restme::Update::RestmeRules"
      #
      # 2. The Rules class may define:
      #    RESTME_UPDATE_ACTIONS_RULES = [:update]
      #
      # 3. Scope methods must follow this format:
      #    "#{action}_#{role}_scope?"
      #
      # Example:
      #   update_admin_scope?
      #   update_manager_scope?
      #
      class Rules
        attr_reader :context

        def initialize(context:)
          @context = context
        end

        # Executes the update flow.
        #
        # Steps:
        # 1. Finds the record by :id
        # 2. Assigns controller params (+ optional custom params)
        # 3. Injects current_user if supported
        # 4. Validates scope rules
        # 5. Persists the record
        # 6. Returns either:
        #    - The updated instance
        #    - A normalized error hash
        #
        # @param restme_update_custom_params [Hash]
        #   Additional params merged into controller_params
        #
        # @return [ActiveRecord::Base, Hash]
        def restme_update(restme_update_custom_params: {})
          @restme_update ||= begin
            @restme_update_custom_params = restme_update_custom_params

            restme_update_set_current_user

            restme_update_instance.assign_attributes(context.controller_params_serialized)

            restme_update_errors.presence || restme_update_instance
          end
        end

        # Returns the appropriate HTTP status symbol
        # based on whether errors exist.
        #
        # @return [Symbol]
        def restme_update_status
          restme_update_errors ? :unprocessable_content : :ok
        end

        private

        # Assigns current_user to the model instance
        # if the model defines `current_user=`.
        def restme_update_set_current_user
          return unless context.current_user
          return unless restme_update_instance.respond_to?(:current_user)

          restme_update_instance.current_user = context.current_user
        end

        # Finds the record and prepares it for update.
        #
        # - Looks up the record using params[:id]
        # - Merges optional custom params
        # - Assigns attributes
        #
        # Memoized.
        #
        # @return [ActiveRecord::Base, nil]
        def restme_update_instance
          @restme_update_instance ||= begin
            record = context.model_class.find_by(id: context.params[:id])

            if record
              params = context.controller_params_serialized
              params = params.merge(@restme_update_custom_params) if @restme_update_custom_params.present?

              record.assign_attributes(params)
              record
            end
          end
        end

        # Resolves error output depending on:
        # - Action declaration
        # - Record existence
        # - Scope validation
        # - ActiveRecord validation errors
        #
        # @return [Hash, nil]
        def restme_update_errors
          return unless restme_update_current_action
          return restme_update_not_found_error if restme_update_instance.blank?
          return restme_update_unscoped_errors unless restme_update_scope?

          restme_update_instance.save

          return if restme_update_instance.errors.blank?

          restme_update_active_record_errors
        end

        # Error returned when record is not found.
        #
        # @return [Hash]
        def restme_update_not_found_error
          {
            errors: "Not found object to id: #{context.params[:id]}"
          }
        end

        # Error returned when no scope rule allows the action.
        #
        # @return [Hash]
        def restme_update_unscoped_errors
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
        def restme_update_scope?
          return true unless context.current_user

          restme_update_methods_scopes.any? do |method_scope|
            restme_update_rules_class_instance.respond_to?(method_scope) &&
              restme_update_rules_class_instance.public_send(method_scope)
          end
        end

        # Builds the list of possible scope methods
        # based on current action and user roles.
        #
        # Example:
        #   update_admin_scope?
        #   update_user_scope?
        #
        # @return [Array<String>]
        def restme_update_methods_scopes
          @restme_update_methods_scopes ||= context.current_user_roles.map do |restme_role|
            "#{restme_update_current_action}_#{restme_role}_scope?"
          end
        end

        # Returns the current action only if it is declared
        # inside RESTME_UPDATE_ACTIONS_RULES.
        #
        # @return [Symbol, nil]
        def restme_update_current_action
          return unless restme_update_rules_class&.const_defined?(:RESTME_UPDATE_ACTIONS_RULES)

          context.action_name.presence_in(
            restme_update_rules_class::RESTME_UPDATE_ACTIONS_RULES
          )
        end

        # Returns validation errors in normalized format.
        #
        # @return [Hash]
        def restme_update_active_record_errors
          {
            errors: restme_update_instance.errors.messages
          }
        end

        # Instantiates the Rules class if it exists.
        #
        # Initialized with:
        #   (instance, current_user, controller_params)
        #
        # @return [Object, nil]
        def restme_update_rules_class_instance
          @restme_update_rules_class_instance ||=
            restme_update_rules_class&.new(
              restme_update_instance,
              context.current_user,
              context.controller_params_serialized
            )
        end

        # Resolves the Rules class dynamically following
        # the naming convention:
        #
        #   "#{ControllerName}Restme::Update::RestmeRules"
        #
        # Uses safe_constantize to avoid raising errors.
        #
        # @return [Class, nil]
        def restme_update_rules_class
          @restme_update_rules_class ||= RestmeRails::RulesFind.new(klass: context.model_class,
                                                                    rule_context: "Update").rule_class
        end
      end
    end
  end
end
