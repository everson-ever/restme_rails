# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      # Executes a sequential pipeline of scope processing steps.
      #
      # Each step in the pipeline must respond to:
      #
      #   process(scope)
      #
      # and return a new ActiveRecord::Relation that will be passed
      # to the next step in the pipeline.
      #
      # Typical pipeline steps include:
      #
      # - filtering
      # - sorting
      # - pagination
      # - field selection
      #
      # The output of one step becomes the input of the next.
      #
      # Example:
      #
      #   pipeline = Pipeline.new([
      #     FilterRules.new(...),
      #     SortRules.new(...),
      #     PaginateRules.new(...)
      #   ])
      #
      #   pipeline.call(Product.all)
      #
      # @example Pipeline flow
      #
      #   initial_scope
      #     -> filter
      #     -> sort
      #     -> paginate
      #     -> fields
      #
      class Pipeline
        # Initializes the pipeline with a list of processing steps.
        #
        # Each step must implement:
        #
        #   process(scope)
        #
        # @param steps [Array<Object>]
        #   List of rule instances that will be executed sequentially.
        def initialize(steps)
          @steps = steps
        end

        # Executes the pipeline.
        #
        # Each step receives the result of the previous step.
        #
        # @param initial_scope [ActiveRecord::Relation]
        #   The starting relation that will be processed.
        #
        # @return [ActiveRecord::Relation]
        #   The final scope after all steps have been applied.
        def call(initial_scope)
          @steps.reduce(initial_scope) do |scope, step|
            step.process(scope)
          end
        end

        # Executes error checks for every pipeline step.
        #
        # Each step is expected to expose an `errors` method
        # that validates parameters or scope rules and registers
        # errors internally if necessary.
        #
        # This method ensures that all validation logic is triggered
        # before executing the pipeline.
        #
        # @return [Array<Object>]
        #   The list of steps after their error checks have been executed.
        def check_scope_errors
          @check_scope_errors ||= @steps.each(&:errors)
        end
      end
    end
  end
end
