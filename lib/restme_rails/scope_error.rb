# frozen_string_literal: true

module RestmeRails
  # Represents the result of a scope execution,
  # including status and collected errors.
  class ScopeError
    attr_reader :restme_scope_errors, :restme_scope_status

    def initialize
      @restme_scope_errors = []
      @restme_scope_status = :ok
    end

    # Adds an error message to the scope error collection.
    #
    # @param scope_error [String, Symbol]
    # @return [void]
    def add_error(scope_error)
      @restme_scope_errors << scope_error
    end

    # Sets the scope status.
    #
    # @param scope_status [Symbol]
    # @return [void]
    def add_status(scope_status)
      @restme_scope_status = scope_status
    end
  end
end
