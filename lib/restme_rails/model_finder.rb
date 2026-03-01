# frozen_string_literal: true

module RestmeRails
  # Responsible for resolving the model class associated with a Rails controller.
  #
  # This class follows a "convention over configuration" strategy:
  #
  # Resolution order:
  #   1. If the controller defines a MODEL_NAME constant, it will be used.
  #   2. Otherwise, the model name is inferred from the controller name.
  #
  # Example (convention-based resolution):
  #
  #   ProductsController
  #   → "ProductsController"
  #   → remove "Controller"
  #   → "Products"
  #   → singularize
  #   → "Product"
  #   → constantize
  #   → Product
  #
  # Example (explicit override):
  #
  #   class Admin::InventoryController < ApplicationController
  #     MODEL_NAME = "Inventory::Product"
  #   end
  #
  #   ModelFinder.new(controller_class: Admin::InventoryController).model_class
  #   # => Inventory::Product
  #
  # @example Basic usage
  #   finder = RestmeRails::ModelFinder.new(controller_class: ProductsController)
  #   finder.model_class
  #   # => Product
  #
  # @note This class assumes ActiveSupport inflection methods are available.
  class ModelFinder
    # @return [Class] The controller class used for model resolution.
    attr_reader :controller_class

    # @param controller_class [Class]
    #   The Rails controller class from which the model will be resolved.
    #
    # @raise [ArgumentError] if controller_class is nil.
    def initialize(controller_class:)
      @controller_class = controller_class
    end

    # Resolves the model class associated with the controller.
    #
    # Resolution strategy:
    #   1. If MODEL_NAME constant is defined in the controller, it is used.
    #   2. Otherwise, the model name is inferred from the controller name.
    #
    # @return [Class] The resolved model class.
    #
    # @raise [NameError]
    #   If the inferred model constant cannot be found.
    def model_class
      return defined_model_name if defined_model_name

      controller_class.name
                      .demodulize
                      .sub("Controller", "")
                      .singularize
                      .constantize
    end

    private

    # Returns the model class defined explicitly via the MODEL_NAME constant.
    #
    # Example:
    #
    #   MODEL_NAME = "Inventory::Product"
    #
    # @return [Class, nil]
    #   The explicitly defined model class, or nil if not defined.
    def defined_model_name
      return unless controller_class.const_defined?(:MODEL_NAME)

      controller_class::MODEL_NAME.constantize
    end
  end
end
