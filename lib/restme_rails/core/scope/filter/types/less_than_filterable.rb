# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        module Types
          # Applies "less than" (<) filtering to a scope.
          #
          # ------------------------------------------------------------------
          # Query Param Convention
          # ------------------------------------------------------------------
          #
          # Expected formats:
          #
          #   ?price_less_than=100
          #   ?created_at_less_than=2024-01-01
          #
          # After serialization, filters may look like:
          #
          #   {
          #     less_than: {
          #       price: 100,
          #       created_at: "2024-01-01"
          #     }
          #   }
          #
          # ------------------------------------------------------------------
          # Generated SQL Example
          # ------------------------------------------------------------------
          #
          #   WHERE products.price < 100
          #     AND products.created_at < '2024-01-01'
          #
          # ------------------------------------------------------------------
          # Security
          # ------------------------------------------------------------------
          #
          # - Uses named parameters (:price)
          # - Prevents SQL injection
          # - Only validated filterable fields are processed upstream
          #
          # ------------------------------------------------------------------
          # Extension Pattern
          # ------------------------------------------------------------------
          #
          # Follows the Filter::Types convention:
          #
          #   - Reads serialized filters
          #   - Applies condition to scope
          #
          class LessThanFilterable
            attr_reader :context

            # @param context [RestmeRails::Context]
            def initialize(context:)
              @context = context
            end

            # Applies the "<" condition to the given scope.
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
            #   "products.price < :price AND products.quantity < :quantity"
            #
            # @return [String]
            def sql(filter_serialized)
              filter_serialized.keys.map do |param|
                "#{qualified_column(param)} < :#{param}"
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
