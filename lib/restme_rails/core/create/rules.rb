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

        # Executes create flow
        #
        # @param custom_params [Hash]
        # @param auto_save [Boolean]
        #
        # @return [ActiveRecord::Base, Hash]
        def create(custom_params: {})
          build(custom_params:)

          instance.save unless errors

          errors || instance
        end

        def create_status
          errors ? :unprocessable_content : :created
        end

        private

        # Builds the instance without persisting
        #
        # @param custom_params [Hash]
        # @return [ActiveRecord::Base]
        def build(custom_params: {})
          @custom_params = custom_params
          set_current_user
          instance
        end

        # -----------------------------
        # Instance
        # -----------------------------

        def instance
          @instance ||= begin
            params = context.controller_params_serialized
            params = params.merge(@custom_params) if @custom_params.present?

            context.model_class.new(params)
          end
        end

        # -----------------------------
        # Current user injection
        # -----------------------------

        def set_current_user
          return unless context.current_user
          return unless instance.respond_to?(:current_user=)

          instance.current_user = context.current_user
        end

        # -----------------------------
        # Errors
        # -----------------------------

        def errors
          return @errors if defined?(@errors)

          @errors = if !scoped_action?
                      nil
                    elsif !scope_allowed?
                      unscoped_errors
                    elsif instance.valid?
                      nil
                    else
                      active_record_errors
                    end
        end

        def unscoped_errors
          { errors: ["Unscoped"] }
        end

        def active_record_errors
          { errors: instance.errors.messages }
        end

        # -----------------------------
        # Scope validation
        # -----------------------------

        def scope_allowed?
          return true unless context.current_user

          scope_methods.any? do |method|
            rules_instance.respond_to?(method) &&
              rules_instance.public_send(method)
          end
        end

        def scope_methods
          context.current_user_roles.map do |role|
            "#{current_action}_#{role}_scope?"
          end
        end

        # -----------------------------
        # Action validation
        # -----------------------------

        def scoped_action?
          return false unless rules_class&.const_defined?(:RESTME_CREATE_ACTIONS_RULES)

          context.action_name.presence_in(
            rules_class::RESTME_CREATE_ACTIONS_RULES
          )
        end

        def current_action
          context.action_name
        end

        # -----------------------------
        # Rules resolution
        # -----------------------------

        def rules_instance
          @rules_instance ||= rules_class&.new(instance, context.current_user)
        end

        def rules_class
          @rules_class ||= RestmeRails::RulesFind
                           .new(
                             klass: context.model_class,
                             rule_context: "Create"
                           ).rule_class
        end
      end
    end
  end
end
