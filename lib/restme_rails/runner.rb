# frozen_string_literal: true

require_relative "core/authorize/rules"
require_relative "core/scope/rules"
require_relative "core/create/rules"
require_relative "core/update/rules"

module RestmeRails
  # Runner is the orchestration layer of RestmeRails.
  #
  # It coordinates execution between the different rule engines:
  #
  #   - Authorize
  #   - Create
  #   - Update
  #   - Scope
  #
  # The Runner does NOT contain business logic.
  # It delegates responsibility to specialized rule classes located under:
  #
  #   RestmeRails::Core::*
  #
  # This keeps responsibilities isolated and makes the system:
  #
  #   • Testable
  #   • Replaceable
  #   • Extensible
  #   • Open/Closed compliant
  #
  # The Runner receives a Context object, which encapsulates
  # everything about the current request (user, params, controller, model).
  #
  # @example
  #
  #   context = RestmeRails::Context.new(user: current_user, controller: adapter)
  #   runner  = RestmeRails::Runner.new(context: context)
  #
  #   runner.authorize!
  #   runner.restme_create
  #
  class Runner
    attr_reader :context

    # @param context [RestmeRails::Context]
    #   The execution context for the current request.
    def initialize(context:)
      @context = context
    end

    # ----------------------------------------
    # Authorization
    # ----------------------------------------

    # Executes authorization rules for the current action.
    #
    # @return [void]
    # @raise [RestmeRails::UnauthorizedError] (if implemented in rules)
    def authorize!
      authorize_rules_instance.authorize!
    end

    # ----------------------------------------
    # Create
    # ----------------------------------------

    # Executes create rules and persists a new record.
    #
    # @param restme_create_custom_params [Hash]
    #   Additional attributes to merge into creation params.
    #
    # @return [Object] The created record (or rule response object)
    def restme_create(restme_create_custom_params: {})
      create_rules_instance.restme_create(
        restme_create_custom_params: restme_create_custom_params
      )
    end

    # Returns HTTP status related to the last create operation.
    #
    # @return [Symbol, Integer]
    def restme_create_status
      create_rules_instance.restme_create_status
    end

    # ----------------------------------------
    # Update
    # ----------------------------------------

    # Executes update rules for the current record.
    #
    # @param restme_update_custom_params [Hash]
    #   Additional attributes to merge into update params.
    #
    # @return [Object] The updated record (or rule response object)
    def restme_update(restme_update_custom_params: {})
      update_rules_instance.restme_update(
        restme_update_custom_params: restme_update_custom_params
      )
    end

    # Returns HTTP status related to the last update operation.
    #
    # @return [Symbol, Integer]
    def restme_update_status
      update_rules_instance.restme_update_status
    end

    # ----------------------------------------
    # Scope / Index
    # ----------------------------------------

    # Returns paginated response metadata and collection.
    #
    # @return [Hash]
    def pagination_response
      scope_rules_instance.pagination_response
    end

    # Returns the scoped ActiveRecord::Relation
    # after all scope rules have been applied.
    #
    # @return [ActiveRecord::Relation]
    def model_scope_object
      scope_rules_instance.model_scope_object
    end

    # Returns HTTP status related to scope execution.
    #
    # @return [Symbol, Integer]
    def restme_scope_status
      scope_rules_instance.restme_scope_status
    end

    private

    # ----------------------------------------
    # Lazy Rule Instantiation
    # ----------------------------------------
    #
    # Rule engines are instantiated lazily and memoized.
    # This prevents unnecessary object allocation when certain
    # operations (e.g., create/update/scope) are not used.
    #
    # This also keeps Runner stateless aside from Context.

    def authorize_rules_instance
      @authorize_rules_instance ||=
        RestmeRails::Core::Authorize::Rules.new(context: context)
    end

    def create_rules_instance
      @create_rules_instance ||=
        RestmeRails::Core::Create::Rules.new(context: context)
    end

    def update_rules_instance
      @update_rules_instance ||=
        RestmeRails::Core::Update::Rules.new(context: context)
    end

    def scope_rules_instance
      @scope_rules_instance ||=
        RestmeRails::Core::Scope::Rules.new(context: context)
    end
  end
end
