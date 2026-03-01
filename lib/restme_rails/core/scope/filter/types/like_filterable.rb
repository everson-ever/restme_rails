# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        module Types
          # Applies partial matching filtering using ILIKE (PostgreSQL).
          #
          # ------------------------------------------------------------------
          # Query Param Convention
          # ------------------------------------------------------------------
          #
          # Expected formats:
          #
          #   ?name_like=john
          #   ?email_like=gmail
          #
          # After serialization, filters may look like:
          #
          #   {
          #     like: {
          #       name: "john",
          #       email: "gmail"
          #     }
          #   }
          #
          # ------------------------------------------------------------------
          # Generated SQL Example
          # ------------------------------------------------------------------
          #
          #   WHERE CAST(users.name AS TEXT) ILIKE '%john%'
          #     AND CAST(users.email AS TEXT) ILIKE '%gmail%'
          #
          # ------------------------------------------------------------------
          # Behavior Notes
          # ------------------------------------------------------------------
          #
          # - Uses ILIKE for case-insensitive matching (PostgreSQL).
          # - Casts column to TEXT to allow matching non-text fields.
          # - Automatically wraps value with "%" for wildcard matching.
          # - Uses named parameters to prevent SQL injection.
          #
          class LikeFilterable
            # Query param suffix used to identify this filter.
            #
            # Example:
            #   name_like
            #
            # @return [Symbol]
            FIELD_SUFFIX = :like

            attr_reader :context, :filters_serialized

            # @param context [RestmeRails::Context]
            # @param filters_serialized [Hash]
            def initialize(context:, filters_serialized:)
              @context = context
              @filters_serialized = filters_serialized[FIELD_SUFFIX]
            end

            # Applies the ILIKE condition to the given scope.
            #
            # Returns original scope if no filters were provided.
            #
            # @param scope [ActiveRecord::Relation]
            # @return [ActiveRecord::Relation]
            def where_like(scope)
              return scope if filters_serialized.blank?

              scope.where(like_sql, wildcarded_filters)
            end

            private

            # Builds SQL fragment for WHERE clause.
            #
            # Example output:
            #   "CAST(users.name AS TEXT) ILIKE :name"
            #
            # @return [String]
            def like_sql
              filters_serialized.keys.map do |param|
                "CAST(#{qualified_column(param)} AS TEXT) ILIKE :#{param}"
              end.join(" AND ")
            end

            # Adds % wildcard to all filter values
            # without mutating the original hash.
            #
            # @return [Hash]
            def wildcarded_filters
              filters_serialized.transform_values do |value|
                "%#{value}%"
              end
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
