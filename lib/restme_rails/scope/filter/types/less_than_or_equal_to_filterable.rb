# frozen_string_literal: true

module Scope
  module Filter
    module Types
      # Implements the "less than or equal to" filtering behavior.
      #
      # Expected query param format:
      #   ?price_less_than_or_equal_to=100
      #   ?created_at_less_than_or_equal_to=2024-01-01
      #
      # This will generate SQL conditions like:
      #   WHERE table_name.price <= 100
      #
      # Only fields previously validated as filterable
      # will be applied to the query.
      module LessThanOrEqualToFilterable
        # Suffix used in query params to identify this filter type.
        # Example: price_less_than_or_equal_to
        FIELD_SUFFIX = :less_than_or_equal_to

        private

        # Applies the "<=" condition to the given scope.
        #
        # Returns the original scope if no valid fields were registered.
        def where_less_than_or_equal_to(scope)
          return scope if less_than_or_equal_to_fields.blank?

          scope.where(less_than_or_equal_to_sql, less_than_or_equal_to_fields)
        end

        # Builds the SQL fragment for the WHERE clause.
        #
        # Example output:
        #   "products.price <= :price AND products.quantity <= :quantity"
        def less_than_or_equal_to_sql
          less_than_or_equal_to_fields.keys.map do |param|
            "#{klass.table_name}.#{param} <= :#{param}"
          end.join(" AND ")
        end

        # Registers a field to be filtered using the "<=" operator.
        #
        # Extracts the raw value from query params and stores it
        # inside the internal params_filters hash.
        #
        # Returns the original param key (e.g., :price_less_than_or_equal_to)
        # so it can be tracked as an allowed filter field.
        def add_less_than_or_equal_to_field(field)
          field_key = :"#{field}_#{FIELD_SUFFIX}"
          field_value = controller_query_params[field_key]

          less_than_or_equal_to_fields[field] = field_value if field_value.present?

          field_key
        end

        # Stores all fields and values that will be used in the
        # "<=" SQL condition.
        #
        # Example:
        #   { price: 100 }
        def less_than_or_equal_to_fields
          params_filters[FIELD_SUFFIX] ||= {}
        end
      end
    end
  end
end
