# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        module Types
          # Applies "greater than" (>) filtering to a scope.
          #
          # ------------------------------------------------------------------
          # Query Param Convention
          # ------------------------------------------------------------------
          #
          # Expected format:
          #
          #   ?price_bigger_than=10
          #   ?quantity_bigger_than=5
          #
          # After filter serialization, this becomes:
          #
          #   {
          #     bigger_than: {
          #       price: 10,
          #       quantity: 5
          #     }
          #   }
          #
          # ------------------------------------------------------------------
          # Generated SQL Example
          # ------------------------------------------------------------------
          #
          #   WHERE products.price > 10
          #     AND products.quantity > 5
          #
          # ------------------------------------------------------------------
          # Security
          # ------------------------------------------------------------------
          #
          # - Uses named parameters (:price) to prevent SQL injection
          # - Only applies to previously validated/allowed fields
          #
          # ------------------------------------------------------------------
          # Extension Strategy
          # ------------------------------------------------------------------
          #
          # This class follows a filter type pattern:
          #
          #   Filter::Types::<FilterName>
          #
          # Each filter type:
          #   - Reads serialized filters
          #   - Applies a WHERE clause
          #
          class BiggerThanFilterable
            attr_reader :context

            # @param context [RestmeRails::Context]
            def initialize(context:)
              @context = context
            end

            # Applies the "greater than" condition.
            #
            # If no filters were provided, returns the original scope unchanged.
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

            # Builds the SQL fragment used in the WHERE clause.
            #
            # Example output:
            #   "products.price > :price AND products.quantity > :quantity"
            #
            # @return [String]
            def sql(filter_serialized)
              filter_serialized.keys.map do |param|
                "#{qualified_column(param)} > :#{param}"
              end.join(" AND ")
            end

            # Fully qualifies a column with its table name.
            #
            # Prevents ambiguity in joins.
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
