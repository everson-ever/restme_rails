# frozen_string_literal: true

module Scope
  module Filter
    module Types
      # Implements the "IN" filtering behavior.
      #
      # Expected query param format:
      #   ?status_in=active,pending
      #   ?id_in=1,2,3
      #
      # This will generate SQL conditions like:
      #   WHERE table_name.status IN ('active', 'pending')
      #   WHERE table_name.id IN (1, 2, 3)
      #
      # Values must be comma-separated.
      # Only fields validated as allowed filterable fields
      # will be applied to the query.
      module InFilterable
        # Suffix used in query params to identify this filter type.
        # Example: status_in
        FIELD_SUFFIX = :in

        private

        # Applies the "IN" condition to the given scope.
        #
        # - Serializes comma-separated values into arrays
        # - Uses named parameters to prevent SQL injection
        #
        # Returns the original scope if no valid fields were registered.
        def where_in(scope)
          return scope if in_fields.blank?

          serialize_in_fields

          scope.where(in_sql, in_fields)
        end

        # Builds the SQL fragment for the WHERE clause.
        #
        # Example output:
        #   "users.status IN (:status) AND users.role IN (:role)"
        def in_sql
          in_fields.keys.map do |param|
            "#{klass.table_name}.#{param} IN (:#{param})"
          end.join(" AND ")
        end

        # Converts comma-separated query param values into arrays.
        #
        # Example:
        #   "1,2,3" → ["1", "2", "3"]
        #
        # Note: values remain strings unless type-casted by ActiveRecord.
        def serialize_in_fields
          in_fields.each do |key, value|
            in_fields[key] = value.split(",").map(&:strip)
          end
        end

        # Registers a field to be filtered using the "IN" operator.
        #
        # Extracts the raw comma-separated value from query params
        # and stores it inside the internal params_filters hash.
        #
        # Returns the original param key (e.g., :status_in)
        # so it can be tracked as an allowed filter field.
        def add_in_field(field)
          field_key = :"#{field}_#{FIELD_SUFFIX}"
          field_value = controller_query_params[field_key]

          in_fields[field] = field_value if field_value

          field_key
        end

        # Stores all fields and values that will be used in the
        # "IN" SQL condition.
        #
        # Example:
        #   { status: "active,pending" }
        def in_fields
          params_filters[FIELD_SUFFIX] ||= {}
        end
      end
    end
  end
end
