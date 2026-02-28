# frozen_string_literal: true

module RestmeRails
  module Shared
    # Resolves the model class associated with the current controller.
    #
    # Resolution strategy:
    # 1. If the controller defines a MODEL_NAME constant,
    #    it will be used as the model reference.
    # 2. Otherwise, the model is inferred from the controller name.
    #
    # Example:
    #   ProductsController -> Product
    #
    # This module assumes conventional Rails naming.
    module CurrentModel
      # Returns the resolved model class.
      #
      # @return [Class] The model associated with the controller
      def klass
        return defined_model_name if defined_model_name

        # Infers model from controller name:
        # ProductsController -> "ProductsController"
        # -> remove "sController"
        # -> "Product"
        # -> constantize
        controller_class.name
                        .demodulize
                        .remove("sController")
                        .constantize
      end

      private

      # Returns the model class defined explicitly via MODEL_NAME constant.
      #
      # Example:
      #   MODEL_NAME = "Inventory::Product"
      #
      # @return [Class, nil]
      def defined_model_name
        return unless controller_class.const_defined?(:MODEL_NAME)

        controller_class::MODEL_NAME.constantize
      end

      # Returns the current controller class.
      #
      # Extracted for readability and testability.
      #
      # @return [Class]
      def controller_class
        self.class
      end
    end
  end
end
