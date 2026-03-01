# frozen_string_literal: true

require_relative "restme_rails/version"
require_relative "restme_rails/configuration"
require_relative "restme_rails/adapters/controller_adapter"
require_relative "restme_rails/context"
require_relative "restme_rails/runner"

# Main integration module for RestmeRails.
#
# This module is intended to be included in Rails controllers.
# It provides a clean public API that delegates execution to
# the internal Runner orchestration layer.
#
# Example:
#
#   class ProductsController < ApplicationController
#     include RestmeRails
#
#     def create
#       if restme_authorized?
#         render json: restme_create, status: restme_create_status
#       end
#     end
#   end
#
module RestmeRails
  class << self
    # Global configuration entrypoint.
    #
    # Example:
    #
    #   RestmeRails.configure do |config|
    #     config.current_user_variable = :current_user
    #   end
    #
    # @yield [RestmeRails::Configuration]
    # @return [void]
    def configure
      yield(Configuration)
    end
  end

  # ------------------------
  # Public API
  # ------------------------

  # Verifies whether the current request is authorized
  # according to configured authorization rules.
  #
  # This method delegates to the internal Runner layer.
  #
  # @return [Boolean] true if authorized, false otherwise
  def restme_authorize!
    restme_runner.authorize!
  end

  # Executes the create rules and returns
  # the serialized response object.
  #
  # @return [Object] The result of the create execution
  def restme_create(restme_create_custom_params: {})
    restme_runner.restme_create(restme_create_custom_params: restme_create_custom_params)
  end

  # Returns the HTTP status symbol for the create action.
  #
  # Example:
  #   :created
  #   :unprocessable_entity
  #
  # @return [Symbol]
  def restme_create_status
    restme_runner.restme_create_status
  end

  # Executes the update rules and returns
  # the serialized response object.
  #
  # @return [Object] The result of the update execution
  def restme_update(restme_update_custom_params: {})
    restme_runner.restme_update(restme_update_custom_params: restme_update_custom_params)
  end

  # Returns the HTTP status symbol for the update action.
  #
  # Example:
  #   :ok
  #   :unprocessable_entity
  #
  # @return [Symbol]
  def restme_update_status
    restme_runner.restme_update_status
  end

  # Returns the pagination metadata structure
  # generated during scope execution.
  #
  # Example:
  #   {
  #     current_page: 1,
  #     total_pages: 5,
  #     total_count: 100
  #   }
  #
  # @return [Hash, nil]
  def pagination_response
    restme_runner.pagination_response
  end

  # Returns the scoped model collection
  # after scope rules execution.
  #
  # @return [ActiveRecord::Relation, Object]
  def model_scope_object
    restme_runner.model_scope_object
  end

  # Returns the HTTP status symbol generated
  # during scope validation.
  #
  # @return [Symbol]
  def restme_scope_status
    restme_runner.restme_scope_status
  end

  private

  # Lazily instantiates the Runner responsible
  # for coordinating rule execution.
  #
  # @return [RestmeRails::Runner]
  def restme_runner
    @restme_runner ||= RestmeRails::Runner.new(context: context)
  end

  # Builds the execution context for the current request.
  #
  # @return [RestmeRails::Context]
  def context
    RestmeRails::Context.new(
      user: resolved_current_user,
      controller: RestmeRails::Adapters::ControllerAdapter.new(self)
    )
  end

  # Dynamically resolves the configured current user method.
  #
  # It reads:
  #   RestmeRails::Configuration.current_user_variable
  #
  # And safely calls it if present.
  #
  # @return [Object, nil]
  def resolved_current_user
    method = ::RestmeRails::Configuration.current_user_variable
    public_send(method) if respond_to?(method)
  end
end
