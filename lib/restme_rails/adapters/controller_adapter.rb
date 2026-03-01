# frozen_string_literal: true

module RestmeRails
  module Adapters
    # Adapter responsible for abstracting a Rails controller.
    #
    # This class isolates direct dependencies on ActionController,
    # allowing the rest of the gem to interact with a normalized
    # controller interface.
    #
    # By using this adapter, the gem avoids tight coupling with
    # Rails internals and makes testing significantly easier.
    #
    # Example usage:
    #
    #   adapter = RestmeRails::Rails::ControllerAdapter.new(controller)
    #
    #   adapter.params
    #   adapter.query_params
    #   adapter.action_name
    #
    # @note This adapter assumes an ActionController-compatible object.
    #
    class ControllerAdapter
      # @return [ActionController::Base]
      #   The underlying Rails controller instance.
      attr_reader :controller

      # @param controller [ActionController::Base]
      #   The controller instance to be wrapped.
      def initialize(controller)
        @controller = controller
      end

      # Returns request parameters.
      #
      # @return [ActionController::Parameters]
      def params
        controller.params
      end

      # Returns URL query parameters as a symbolized Hash.
      #
      # Example:
      #   GET /products?name=foo
      #   => { name: "foo" }
      #
      # @return [Hash]
      def query_params
        return {} unless controller.respond_to?(:request)

        controller.request.query_parameters.deep_symbolize_keys
      end

      # Returns the underlying request object.
      #
      # @return [ActionDispatch::Request]
      def request
        controller.request
      end

      # Returns the current action name.
      #
      # @return [String]
      def action_name
        controller.action_name
      end

      # Returns the controller class.
      #
      # @return [Class]
      def controller_class
        controller.class
      end
    end
  end
end
