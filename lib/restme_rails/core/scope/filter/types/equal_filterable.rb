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
          #   - Reads serialized filters
          #   - Applies condition to scope
          #
          class EqualFilterable
            attr_reader :context

            # @param context [RestmeRails::Context]
            def initialize(context:)
              @context = context
            end

            # Applies the "=" condition to the given scope.
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
            #   "users.name = :name AND users.status = :status"
            #
            # @return [String]
            def sql(filter_serialized)
              filter_serialized.keys.map do |param|
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
