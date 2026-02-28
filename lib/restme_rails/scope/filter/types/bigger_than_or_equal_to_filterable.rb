# frozen_string_literal: true

module Scope
  module Filter
    module Types
      # Implements the "greater than or equal to" (>=) filtering behavior.
      #
      # Expected query param format:
      #   ?price_bigger_than_or_equal_to=10
      #
      # This will generate a SQL condition like:
      #   WHERE table_name.price >= 10
      #
      # Only fields previously validated as allowed filterable fields
      # will be applied to the query.
      module BiggerThanOrEqualToFilterable
        # Suffix used in query params to identify this filter type.
        # Example: price_bigger_than_or_equal_to
        FIELD_SUFFIX = :bigger_than_or_equal_to

        private

        # Applies the "greater than or equal to" condition to the given scope.
        #
        # Returns the original scope if no valid fields were registered.
        def where_bigger_than_or_equal_to(scope)
          return scope if bigger_than_or_equal_to_fields.blank?

          scope.where(bigger_than_or_equal_to_sql, bigger_than_or_equal_to_fields)
        end

        # Builds the SQL fragment for the WHERE clause.
        #
        # Example output:
        #   "products.price >= :price AND products.quantity >= :quantity"
        #
        # Uses named parameters to ensure SQL injection protection.
        def bigger_than_or_equal_to_sql
          bigger_than_or_equal_to_fields.keys.map do |param|
            "#{klass.table_name}.#{param} >= :#{param}"
          end.join(" AND ")
        end

        # Registers a field to be filtered using the ">=" operator.
        #
        # Extracts the value from query params and stores it inside
        # the internal params_filters hash under the FIELD_SUFFIX key.
        #
        # Returns the original param key (e.g., :price_bigger_than_or_equal_to)
        # so it can be tracked as an allowed filter field.
        def add_bigger_than_or_equal_to_field(field)
          field_key = :"#{field}_#{FIELD_SUFFIX}"
          field_value = controller_query_params[field_key]

          bigger_than_or_equal_to_fields[field] = field_value if field_value

          field_key
        end

        # Stores all fields and values that will be used in the
        # ">=" SQL condition.
        #
        # Example:
        #   { price: 10, quantity: 5 }
        def bigger_than_or_equal_to_fields
          params_filters[FIELD_SUFFIX] ||= {}
        end
      end
    end
  end
end
