# frozen_string_literal: true

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
      #    declared via restme_authorize_action DSL → access is allowed.
      # 3. Otherwise → raises NotAuthorizedError.
      #
      # ------------------------------------------------------------
      # Expected Convention
      # ------------------------------------------------------------
      #
      # Roles are declared on the controller class using the DSL:
      #
      #   class ProductsController < ApplicationController
      #     include RestmeRails
      #
      #     restme_authorize_action :index,  %i[admin manager]
      #     restme_authorize_action :create, %i[admin]
      #     restme_authorize_action %i[index show], %i[admin manager]
      #   end
      #
      class Rules
        attr_reader :context

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

          raise RestmeRails::NotAuthorizedError, "You are not allowed to access this resource"
        end

        private

        # Checks if user roles intersect allowed roles for action.
        #
        # @return [Boolean]
        def authorized?
          allowed_roles_for_action.intersect?(context.current_user_roles)
        end

        # Returns allowed roles for current action from the controller DSL.
        #
        # @return [Array<Symbol>]
        def allowed_roles_for_action
          context.controller_class.restme_authorize_actions[context.action_name] || []
        end
      end
    end
  end
end
