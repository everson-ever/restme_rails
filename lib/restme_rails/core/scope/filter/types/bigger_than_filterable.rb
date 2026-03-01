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
          #   - Defines a FIELD_SUFFIX
          #   - Reads serialized filters
          #   - Applies a WHERE clause
          #
          class BiggerThanFilterable
            # Suffix used to identify this filter type in query params.
            #
            # Example:
            #   price_bigger_than
            #
            # @return [Symbol]
            FIELD_SUFFIX = :bigger_than

            attr_reader :context, :filters_serialized

            # @param context [RestmeRails::Context]
            # @param filters_serialized [Hash]
            #
            # filters_serialized example:
            #   {
            #     bigger_than: { price: 10 }
            #   }
            def initialize(context:, filters_serialized:)
              @context = context
              @filters_serialized = filters_serialized[FIELD_SUFFIX]
            end

            # Applies the "greater than" condition.
            #
            # If no filters were provided, returns the original scope unchanged.
            #
            # @param scope [ActiveRecord::Relation]
            # @return [ActiveRecord::Relation]
            def where_bigger_than(scope)
              return scope if filters_serialized.blank?

              scope.where(bigger_than_sql, filters_serialized)
            end

            private

            # Builds the SQL fragment used in the WHERE clause.
            #
            # Example output:
            #   "products.price > :price AND products.quantity > :quantity"
            #
            # @return [String]
            def bigger_than_sql
              filters_serialized.keys.map do |param|
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
