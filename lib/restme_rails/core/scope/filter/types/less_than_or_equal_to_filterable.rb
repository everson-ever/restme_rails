# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        module Types
          # Applies "less than or equal to" (<=) filtering to a scope.
          #
          # ------------------------------------------------------------------
          # Query Param Convention
          # ------------------------------------------------------------------
          #
          # Expected formats:
          #
          #   ?price_less_than_or_equal_to=100
          #   ?created_at_less_than_or_equal_to=2024-01-01
          #
          # After serialization, filters may look like:
          #
          #   {
          #     less_than_or_equal_to: {
          #       price: 100,
          #       created_at: "2024-01-01"
          #     }
          #   }
          #
          # ------------------------------------------------------------------
          # Generated SQL Example
          # ------------------------------------------------------------------
          #
          #   WHERE products.price <= 100
          #     AND products.created_at <= '2024-01-01'
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
          #   - Defines FIELD_SUFFIX
          #   - Reads serialized filters
          #   - Applies condition to scope
          #
          class LessThanOrEqualToFilterable
            # Query param suffix used to identify this filter.
            #
            # Example:
            #   price_less_than_or_equal_to
            #
            # @return [Symbol]
            FIELD_SUFFIX = :less_than_or_equal_to

            attr_reader :context, :filters_serialized

            # @param context [RestmeRails::Context]
            # @param filters_serialized [Hash]
            #
            # Example input:
            #   {
            #     less_than_or_equal_to: { price: 100 }
            #   }
            def initialize(context:, filters_serialized:)
              @context = context
              @filters_serialized = filters_serialized[FIELD_SUFFIX]
            end

            # Applies the "<=" condition to the given scope.
            #
            # Returns original scope if no filters were provided.
            #
            # @param scope [ActiveRecord::Relation]
            # @return [ActiveRecord::Relation]
            def where_less_than_or_equal_to(scope)
              return scope if filters_serialized.blank?

              scope.where(less_than_or_equal_to_sql, filters_serialized)
            end

            private

            # Builds SQL fragment for WHERE clause.
            #
            # Example output:
            #   "products.price <= :price AND products.quantity <= :quantity"
            #
            # @return [String]
            def less_than_or_equal_to_sql
              filters_serialized.keys.map do |param|
                "#{qualified_column(param)} <= :#{param}"
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
