# frozen_string_literal: true

module RestmeRails
  module Shared
    # Provides normalized access to controller parameters.
    #
    # This module extracts:
    # - Body parameters
    # - Query string parameters
    #
    # All returned hashes are symbolized.
    module ControllerParams
      # Returns all request parameters (body + query),
      # excluding Rails internal keys (:controller, :action).
      #
      # If params are wrapped inside the model key:
      #   { product: { name: "foo" } }
      # it returns:
      #   { name: "foo" }
      #
      # NOTE:
      # All parameters are fully permitted using `permit!`.
      # It is strongly recommended to use a JSON schema
      # or another validation layer to filter allowed attributes.
      def controller_params
        @controller_params ||= begin
          # Convert ActionController::Parameters into a plain Hash
          # Permits all attributes (no strong parameter filtering here)
          hash =
            if params_filtered.respond_to?(:permit!)
              params_filtered.permit!.to_h
            else
              params_filtered.to_h
            end

          # Extract nested params under the model key
          # Example: { product: {...} }
          klass_key_param = hash[klass.name.downcase.to_sym]

          # Return extracted params or full hash, symbolized
          (klass_key_param || hash).deep_symbolize_keys
        end
      end

      # Returns only URL query string parameters.
      #
      # Example:
      #   GET /products?page=2
      #   => { page: 2 }
      def controller_query_params
        @controller_query_params ||= request.query_parameters.deep_symbolize_keys
      end

      private

      # Returns only user-sent parameters,
      # removing Rails internal routing keys.
      #
      # Removes:
      # - :controller
      # - :action
      def params_filtered
        params.except(:controller, :action)
      end
    end
  end
end
