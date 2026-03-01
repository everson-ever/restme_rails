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
          #   - Defines FIELD_SUFFIX
          #   - Reads serialized filters
          #   - Applies condition to scope
          #
          class BiggerThanOrEqualToFilterable
            # Query param suffix used to identify this filter.
            #
            # Example:
            #   price_bigger_than_or_equal_to
            #
            # @return [Symbol]
            FIELD_SUFFIX = :bigger_than_or_equal_to

            attr_reader :context, :filters_serialized

            # @param context [RestmeRails::Context]
            # @param filters_serialized [Hash]
            #
            # Example input:
            #   {
            #     bigger_than_or_equal_to: { price: 10 }
            #   }
            def initialize(context:, filters_serialized:)
              @context = context
              @filters_serialized = filters_serialized[FIELD_SUFFIX]
            end

            # Applies the >= condition to the given scope.
            #
            # Returns original scope if no filters were provided.
            #
            # @param scope [ActiveRecord::Relation]
            # @return [ActiveRecord::Relation]
            def where_bigger_than_or_equal_to(scope)
              return scope if filters_serialized.blank?

              scope.where(bigger_than_or_equal_to_sql, filters_serialized)
            end

            private

            # Builds SQL fragment for WHERE clause.
            #
            # Example output:
            #   "products.price >= :price AND products.quantity >= :quantity"
            #
            # @return [String]
            def bigger_than_or_equal_to_sql
              filters_serialized.keys.map do |param|
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
