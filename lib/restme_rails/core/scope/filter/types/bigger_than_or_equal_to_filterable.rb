# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        module Types
          # Applies "greater than or equal to" (>=) filtering to a scope.
          #
          # ------------------------------------------------------------------
          # Query Param Convention
          # ------------------------------------------------------------------
          #
          # Expected format:
          #
          #   ?price_bigger_than_or_equal_to=10
          #   ?quantity_bigger_than_or_equal_to=5
          #
          # After serialization, filters may look like:
          #
          #   {
          #     bigger_than_or_equal_to: {
          #       price: 10,
          #       quantity: 5
          #     }
          #   }
          #
          # ------------------------------------------------------------------
          # Generated SQL Example
          # ------------------------------------------------------------------
          #
          #   WHERE products.price >= 10
          #     AND products.quantity >= 5
          #
          # ------------------------------------------------------------------
          # Security
          # ------------------------------------------------------------------
          #
          # - Uses named parameters (:price)
          # - Prevents SQL injection
          # - Applies only to validated filterable fields
          #
          # ------------------------------------------------------------------
          # Extension Pattern
          # ------------------------------------------------------------------
          #
          # Follows the Filter::Types contract:
          #
          #   - Reads serialized filters
          #   - Applies condition to scope
          #
          class BiggerThanOrEqualToFilterable
            attr_reader :context

            # @param context [RestmeRails::Context]
            def initialize(context:)
              @context = context
            end

            # Applies the >= condition to the given scope.
            #
            # Returns original scope if no filters were provided.
            #
            # @param scope [ActiveRecord::Relation]
            # @param filter_serialized [Hash]
            #
            # filter_serialized example:
            #
            #   { price: 10 }
            #
            # @return [ActiveRecord::Relation]
            def filter(scope, filter_serialized)
              scope.where(sql(filter_serialized), filter_serialized)
            end

            private

            # Builds SQL fragment for WHERE clause.
            #
            # Example output:
            #   "products.price >= :price AND products.quantity >= :quantity"
            #
            # @return [String]
            def sql(filter_serialized)
              filter_serialized.keys.map do |param|
                "#{qualified_column(param)} >= :#{param}"
              end.join(" AND ")
            end

            # Qualifies column with table name to avoid ambiguity.
            #
            # @param column [Symbol]
            # @return [String]
            def qualified_column(column)
              "#{context.model_class.table_name}.#{column}"
            end
          end
        end
      end
    end
  end
end
