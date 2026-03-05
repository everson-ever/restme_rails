# frozen_string_literal: true

module RestmeRails
  # Represents the result of a scope execution,
  # including status and collected errors.
  class ScopeError
    attr_reader :scope_errors, :scope_status

    def initialize
      @scope_errors = []
      @scope_status = :ok
    end

    # Adds an error message to the scope error collection.
    #
    # @param scope_error [String, Symbol]
    # @return [void]
    def add_error(scope_error)
      @scope_errors << scope_error
    end

    # Sets the scope status.
    #
    # @param scope_status [Symbol]
    # @return [void]
    def add_status(scope_status)
      @scope_status = scope_status
    end
  end
end
