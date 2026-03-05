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
            attr_reader :context

            # @param context [RestmeRails::Context]
            def initialize(context:)
              @context = context
            end

            # Applies the ILIKE condition to the given scope.
            #
            # Returns original scope if no filters were provided.
            #
            # @param scope [ActiveRecord::Relation]
            # @param filter_serialized [Hash]
            #
            # filter_serialized example:
            #
            #   { name: "foo" }
            #
            # @return [ActiveRecord::Relation]
            def filter(scope, filter_serialized)
              scope.where(sql(filter_serialized), wildcarded_filters(filter_serialized))
            end

            private

            # Builds SQL fragment for WHERE clause.
            #
            # Example output:
            #   "CAST(users.name AS TEXT) ILIKE :name"
            #
            # @return [String]
            def sql(filter_serialized)
              filter_serialized.keys.map do |param|
                "CAST(#{qualified_column(param)} AS TEXT) ILIKE :#{param}"
              end.join(" AND ")
            end

            # Adds % wildcard to all filter values
            # without mutating the original hash.
            #
            # @return [Hash]
            def wildcarded_filters(filter_serialized)
              filter_serialized.transform_values do |value|
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
