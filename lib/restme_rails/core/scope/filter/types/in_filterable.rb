# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        module Types
          # Applies "IN" filtering to a scope.
          #
          # ------------------------------------------------------------------
          # Query Param Convention
          # ------------------------------------------------------------------
          #
          # Expected formats:
          #
          #   ?status_in=active,pending
          #   ?id_in=1,2,3
          #
          # Values MUST be comma-separated.
          #
          # After serialization, filters may look like:
          #
          #   {
          #     in: {
          #       status: "active,pending",
          #       id: "1,2,3"
          #     }
          #   }
          #
          # ------------------------------------------------------------------
          # Generated SQL Example
          # ------------------------------------------------------------------
          #
          #   WHERE users.status IN ('active', 'pending')
          #     AND users.id IN (1, 2, 3)
          #
          # ------------------------------------------------------------------
          # Security
          # ------------------------------------------------------------------
          #
          # - Uses named parameters
          # - Relies on ActiveRecord binding for SQL injection protection
          # - Only validated filterable fields are processed upstream
          #
          # ------------------------------------------------------------------
          # Extension Contract
          # ------------------------------------------------------------------
          #
          # Follows the Filter::Types convention:
          #
          #   - Defines FIELD_SUFFIX
          #   - Reads serialized filters
          #   - Applies condition to scope
          #
          class InFilterable
            # Query param suffix used to identify this filter type.
            #
            # Example:
            #   status_in
            #
            # @return [Symbol]
            FIELD_SUFFIX = :in

            attr_reader :context, :filters_serialized

            # @param context [RestmeRails::Context]
            # @param filters_serialized [Hash]
            #
            # Example input:
            #   {
            #     in: { status: "active,pending" }
            #   }
            def initialize(context:, filters_serialized:)
              @context = context
              @filters_serialized = normalize_filters(filters_serialized[FIELD_SUFFIX])
            end

            # Applies the "IN" condition to the given scope.
            #
            # Returns original scope if no filters were provided.
            #
            # @param scope [ActiveRecord::Relation]
            # @return [ActiveRecord::Relation]
            def where_in(scope)
              return scope if filters_serialized.blank?

              scope.where(in_sql, filters_serialized)
            end

            private

            # Converts comma-separated values into arrays.
            #
            # Example:
            #   { status: "active,pending" }
            #
            # Becomes:
            #   { status: ["active", "pending"] }
            #
            # @param raw_filters [Hash, nil]
            # @return [Hash, nil]
            def normalize_filters(raw_filters)
              return if raw_filters.blank?

              raw_filters.transform_values do |value|
                value.to_s.split(",").map(&:strip)
              end
            end

            # Builds SQL fragment for WHERE clause.
            #
            # Example output:
            #   "users.status IN (:status) AND users.role IN (:role)"
            #
            # @return [String]
            def in_sql
              filters_serialized.keys.map do |param|
                "#{qualified_column(param)} IN (:#{param})"
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
