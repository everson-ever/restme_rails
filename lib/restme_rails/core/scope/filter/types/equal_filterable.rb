# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        module Types
          # Applies "equal" (=) filtering to a scope.
          #
          # ------------------------------------------------------------------
          # Query Param Convention
          # ------------------------------------------------------------------
          #
          # Expected formats:
          #
          #   ?name_equal=John
          #   ?status_equal=active
          #
          # Also supports ID-style filtering (when normalized upstream):
          #
          #   ?id_equal=10
          #
          # After serialization, filters may look like:
          #
          #   {
          #     equal: {
          #       name: "John",
          #       status: "active"
          #     }
          #   }
          #
          # ------------------------------------------------------------------
          # Generated SQL Example
          # ------------------------------------------------------------------
          #
          #   WHERE users.name = 'John'
          #     AND users.status = 'active'
          #
          # ------------------------------------------------------------------
          # Security
          # ------------------------------------------------------------------
          #
          # - Uses named parameters (:name)
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
          class EqualFilterable
            # Query param suffix used to identify this filter.
            #
            # Example:
            #   name_equal
            #
            # @return [Symbol]
            FIELD_SUFFIX = :equal

            attr_reader :context, :filters_serialized

            # @param context [RestmeRails::Context]
            # @param filters_serialized [Hash]
            #
            # Example input:
            #   {
            #     equal: { name: "John" }
            #   }
            def initialize(context:, filters_serialized:)
              @context = context
              @filters_serialized = filters_serialized[FIELD_SUFFIX]
            end

            # Applies the "=" condition to the given scope.
            #
            # Returns original scope if no filters were provided.
            #
            # @param scope [ActiveRecord::Relation]
            # @return [ActiveRecord::Relation]
            def where_equal(scope)
              return scope if filters_serialized.blank?

              scope.where(equal_sql, filters_serialized)
            end

            private

            # Builds SQL fragment for WHERE clause.
            #
            # Example output:
            #   "users.name = :name AND users.status = :status"
            #
            # @return [String]
            def equal_sql
              filters_serialized.keys.map do |param|
                "#{qualified_column(param)} = :#{param}"
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
