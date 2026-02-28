# frozen_string_literal: true

module Scope
  module Filter
    module Types
      # Implements the "LIKE" filtering behavior for partial matching.
      #
      # Expected query param format:
      #   ?name_like=john
      #   ?email_like=gmail
      #
      # This will generate SQL conditions like:
      #   WHERE CAST(table_name.name AS TEXT) ILIKE '%john%'
      #
      # Notes:
      # - Uses ILIKE for case-insensitive matching (PostgreSQL).
      # - Casts field to TEXT to allow partial matching on non-text columns.
      # - Automatically wraps the value with "%" for wildcard matching.
      #
      # Only fields previously validated as filterable
      # will be applied to the query.
      module LikeFilterable
        # Suffix used in query params to identify this filter type.
        # Example: name_like
        FIELD_SUFFIX = :like

        private

        # Applies the ILIKE condition to the given scope.
        #
        # Returns the original scope if no valid fields were registered.
        def where_like(scope)
          return scope if like_fields.blank?

          scope.where(like_sql, like_fields)
        end

        # Builds the SQL fragment for the WHERE clause.
        #
        # Example output:
        #   "CAST(users.name AS TEXT) ILIKE :name"
        #
        # Uses named parameters to prevent SQL injection.
        def like_sql
          like_fields.keys.map do |param|
            "CAST(#{klass.table_name}.#{param} AS TEXT) ILIKE :#{param}"
          end.join(" AND ")
        end

        # Registers a field to be filtered using the ILIKE operator.
        #
        # - Extracts the value from query params
        # - Wraps it with "%" for partial matching
        # - Stores it inside the internal params_filters hash
        #
        # Example:
        #   "john" → "%john%"
        #
        # Returns the original param key (e.g., :name_like)
        # so it can be tracked as an allowed filter field.
        def add_like_field(field)
          field_key = :"#{field}_#{FIELD_SUFFIX}"
          field_value = controller_query_params[field_key].to_s

          field_value = "%#{field_value}%" if field_value.present?
          like_fields[field] = field_value if field_value.present?

          field_key
        end

        # Stores all fields and values that will be used in the
        # ILIKE SQL condition.
        #
        # Example:
        #   { name: "%john%" }
        def like_fields
          params_filters[FIELD_SUFFIX] ||= {}
        end
      end
    end
  end
end
