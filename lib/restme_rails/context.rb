# frozen_string_literal: true

require_relative "model_finder"
require_relative "params_serializer"
require_relative "user_roles_resolver"

module RestmeRails
  # Context object responsible for encapsulating all request-level
  # information required by Restme rule engines.
  #
  # This class acts as a boundary between Rails controllers and
  # the internal rule system of the gem.
  #
  # It extracts and normalizes:
  # - Request parameters
  # - Query parameters
  # - Current user
  # - User roles
  # - Model class
  # - Action name
  #
  # The goal is to avoid tight coupling between rules and
  # ActionController directly.
  #
  # @example
  #   context = RestmeRails::Context.new(
  #     user: current_user,
  #     controller: ControllerAdapter.new(self)
  #   )
  #
  #   context.model_class
  #   # => Product
  #
  #   context.action_name
  #   # => :create
  #
  class Context
    # @return [Object]
    #   Adapter wrapping the Rails controller.
    attr_reader :controller_adapter

    # @param user [Object, nil]
    #   Current authenticated user.
    #
    # @param controller [ControllerAdapter]
    #   Adapter object that abstracts ActionController.
    def initialize(user:, controller:)
      @user = user
      @controller_adapter = controller
    end

    # Returns normalized and serialized controller params.
    #
    # Behavior:
    # - Removes :controller and :action keys
    # - Permits all parameters (no strong params enforcement here)
    # - Extracts nested params under model key
    #   Example:
    #     { product: { name: "Book" } }
    # - Deep symbolized keys
    #
    # @return [Hash]
    def controller_params_serialized
      @controller_params_serialized ||= params_serializer_instance.params_serialized
    end

    # Raw params from controller
    #
    # @return [ActionController::Parameters, Hash]
    def params
      params_serializer_instance.params
    end

    # Query string parameters only
    #
    # @return [Hash]
    def query_params
      params_serializer_instance.query_params
    end

    # Request object
    #
    # @return [ActionDispatch::Request]
    def request
      controller_adapter.request
    end

    # Controller class
    #
    # @return [Class]
    def controller_class
      controller_adapter.controller_class
    end

    # Model class inferred from controller
    #
    # @return [Class]
    def model_class
      RestmeRails::ModelFinder
        .new(controller_class: controller_class)
        .model_class
    end

    # Action name symbol
    #
    # @return [Symbol]
    def action_name
      controller_adapter.action_name.to_sym
    end

    # Current authenticated user
    #
    # @return [Object, nil]
    def current_user
      @user
    end

    def current_user_roles
      ::RestmeRails::UserRolesResolver.new(current_user: current_user).current_user_roles
    end

    private

    def params_serializer_instance
      @params_serializer_instance ||= ParamsSerializer.new(controller: controller_adapter, model_class: model_class)
    end
  end
end
