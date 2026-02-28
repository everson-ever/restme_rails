# frozen_string_literal: true

module Scope
  module Filter
    module Types
      # Implements the "greater than" (>) filtering behavior.
      #
      # Expected query param format:
      #   ?price_bigger_than=10
      #
      # This will generate a SQL condition like:
      #   WHERE table_name.price > 10
      #
      # The filter only applies to fields previously validated as allowed.
      module BiggerThanFilterable
        # Suffix used in query params to identify the filter type.
        # Example: price_bigger_than
        FIELD_SUFFIX = :bigger_than

        private

        # Applies the "greater than" condition to the given scope.
        # Returns the original scope if no valid fields were provided.
        def where_bigger_than(scope)
          return scope if bigger_than_fields.blank?

          scope.where(bigger_than_sql, bigger_than_fields)
        end

        # Builds the SQL fragment used in the WHERE clause.
        # Example output:
        #   "products.price > :price AND products.quantity > :quantity"
        #
        # Named parameters are used to prevent SQL injection.
        def bigger_than_sql
          bigger_than_fields.keys.map do |param|
            "#{klass.table_name}.#{param} > :#{param}"
          end.join(" AND ")
        end

        # Registers a field to be filtered using the "greater than" operator.
        #
        # It extracts the value from query params and stores it in
        # the internal params_filters hash under the FIELD_SUFFIX key.
        #
        # Returns the original param key (e.g., :price_bigger_than)
        # so the caller can track allowed fields.
        def add_bigger_than_field(field)
          field_key = :"#{field}_#{FIELD_SUFFIX}"
          field_value = controller_query_params[field_key]

          bigger_than_fields[field] = field_value if field_value

          field_key
        end

        # Stores all fields and values that will be used in the
        # "greater than" SQL condition.
        #
        # Example:
        #   { price: 10, quantity: 5 }
        def bigger_than_fields
          params_filters[FIELD_SUFFIX] ||= {}
        end
      end
    end
  end
end
