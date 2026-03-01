# frozen_string_literal: true

require_relative "model_finder"

module RestmeRails
  # Responsible for normalizing and serializing controller parameters
  # into a format usable by Restme rule engines.
  #
  # This object:
  # - Removes Rails routing keys (:controller, :action)
  # - Converts ActionController::Parameters into a plain Hash
  # - Permits all parameters (does NOT enforce strong parameters)
  # - Extracts nested params under the model key (if present)
  # - Deep-symbolizes all keys
  #
  # Example:
  #
  #   # Incoming params:
  #   {
  #     controller: "products",
  #     action: "create",
  #     product: { name: "Book", price: 10 }
  #   }
  #
  #   serializer.params_serialized
  #   # => { name: "Book", price: 10 }
  #
  # If no model key is present:
  #
  #   { name: "Book", price: 10 }
  #
  # It returns the entire hash symbolized.
  #
  # @note This class does not enforce strong parameters.
  #   Parameter safety remains the responsibility of the host application.
  #
  # @note Relies on ActiveSupport extensions:
  #   - deep_symbolize_keys
  #   - permit!
  #
  class ParamsSerializer
    # @return [Object]
    #   Adapter wrapping the Rails controller.
    attr_reader :controller_adapter

    # @return [Class]
    #   The model class used to extract nested parameters.
    attr_reader :model_class

    # @param controller [ControllerAdapter]
    #   Adapter that abstracts ActionController.
    #
    # @param model_class [Class]
    #   Model used to determine param nesting key.
    def initialize(controller:, model_class:)
      @controller_adapter = controller
      @model_class = model_class
    end

    # Returns normalized request parameters.
    #
    # Behavior:
    # - Removes :controller and :action keys
    # - Permits all attributes if ActionController::Parameters
    # - Extracts nested params using model key
    # - Deep-symbolizes keys
    #
    # @return [Hash]
    def params_serialized
      @params_serialized ||= begin
        hash =
          if params_filtered.respond_to?(:permit!)
            params_filtered.permit!.to_h
          else
            params_filtered.to_h
          end

        klass_key_param = hash[model_class.model_name.param_key.to_sym]

        (klass_key_param || hash).deep_symbolize_keys
      end
    end

    # Raw controller params.
    #
    # @return [ActionController::Parameters, Hash]
    def params
      controller_adapter.params
    end

    # Query string parameters.
    #
    # @return [Hash]
    def query_params
      controller_adapter.query_params
    end

    private

    # Removes internal Rails routing keys.
    #
    # @return [Hash]
    def params_filtered
      controller_adapter.params.except(:controller, :action)
    end
  end
end
