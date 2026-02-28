# frozen_string_literal: true

module Scope
  module Filter
    module Types
      # Implements the "equal" (=) filtering behavior.
      #
      # Expected query param formats:
      #   ?name_equal=John
      #   ?status_equal=active
      #
      # It also supports direct ID-style filtering:
      #   ?id=10
      #
      # This will generate SQL conditions like:
      #   WHERE table_name.name = 'John'
      #   WHERE table_name.id = 10
      #
      # Only fields validated as allowed filterable fields
      # will be applied to the query.
      module EqualFilterable
        # Suffix used in query params to identify this filter type.
        # Example: name_equal
        FIELD_SUFFIX = :equal

        private

        # Applies the "=" condition to the given scope.
        #
        # Returns the original scope if no valid fields were registered.
        def where_equal(scope)
          return scope if equal_fields.blank?

          scope.where(equal_sql, equal_fields)
        end

        # Builds the SQL fragment for the WHERE clause.
        #
        # Example output:
        #   "users.name = :name AND users.status = :status"
        #
        # Uses named parameters to ensure SQL injection protection.
        def equal_sql
          equal_fields.keys.map do |param|
            "#{klass.table_name}.#{param} = :#{param}"
          end.join(" AND ")
        end

        # Registers a field to be filtered using the "=" operator.
        #
        # Priority order for value resolution:
        #   1. controller_query_params[:field_equal]
        #   2. params[:field] (fallback, useful for ID filtering)
        #
        # Returns the original param key (e.g., :name_equal)
        # so it can be tracked as an allowed filter field.
        def add_equal_field(field)
          field_key = :"#{field}_#{FIELD_SUFFIX}"
          field_value = controller_query_params[field_key] || params[field]

          equal_fields[field] = field_value if field_value

          field_key
        end

        # Stores all fields and values that will be used in the
        # "=" SQL condition.
        #
        # Example:
        #   { name: "John", status: "active" }
        def equal_fields
          params_filters[FIELD_SUFFIX] ||= {}
        end
      end
    end
  end
end
