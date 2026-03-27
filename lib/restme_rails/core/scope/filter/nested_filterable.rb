# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        # Handles filtering by nested association fields.
        #
        # Responsible for applying JOINs and WHERE clauses when the filter
        # targets a field on an associated table rather than the model itself.
        #
        # ------------------------------------------------------------------
        # Query Param Convention
        # ------------------------------------------------------------------
        #
        # Format:
        #
        #   ?#{association}[#{field}_#{filter_type}]=value
        #
        # Examples:
        #
        #   ?establishment[name_equal]=Foo
        #   ?establishment[name_like]=oo
        #   ?establishment[id_bigger_than]=5
        #
        # ------------------------------------------------------------------
        # Declaration
        # ------------------------------------------------------------------
        #
        # The model must declare which nested fields are filterable:
        #
        #   NESTED_FILTERABLE_FIELDS = {
        #     establishment: %i[name]
        #   }.freeze
        #
        # ------------------------------------------------------------------
        # Generated SQL Example
        # ------------------------------------------------------------------
        #
        #   INNER JOIN establishments ON establishments.id = products.establishment_id
        #   WHERE establishments.name = 'Foo'
        #
        # ------------------------------------------------------------------
        # NULL Association Behaviour
        # ------------------------------------------------------------------
        #
        # INNER JOIN is used intentionally.
        #
        # Records whose foreign key is NULL (e.g. products with no
        # establishment) are excluded from the result set as soon as the JOIN
        # is applied, before the WHERE clause is evaluated.
        #
        # This is the expected semantic: filtering by an associated field only
        # makes sense for records that actually have that association.
        #
        # Example:
        #
        #   ?establishment[name_equal]=Foo
        #
        #   → products with establishment_id = nil are NOT returned,
        #     even if no establishment named "Foo" would match them anyway.
        #
        class NestedFilterable
          SQL_TEMPLATES = {
            equal: "%<table>s.%<field>s = :%<key>s",
            like: "CAST(%<table>s.%<field>s AS TEXT) ILIKE :%<key>s",
            bigger_than: "%<table>s.%<field>s > :%<key>s",
            less_than: "%<table>s.%<field>s < :%<key>s",
            bigger_than_or_equal_to: "%<table>s.%<field>s >= :%<key>s",
            less_than_or_equal_to: "%<table>s.%<field>s <= :%<key>s",
            in: "%<table>s.%<field>s IN (:%<key>s)"
          }.freeze

          # @param context [RestmeRails::Context]
          def initialize(context:)
            @context = context
          end

          # Joins the association and applies the filter.
          #
          # Prefer apply_where when the JOIN is already present on the scope
          # (e.g. multiple filter types on the same association) to avoid
          # duplicate JOINs.
          #
          # @param scope  [ActiveRecord::Relation]
          # @param assoc  [Symbol] e.g. :establishment
          # @param filter_type [Symbol] e.g. :equal
          # @param fields [Hash] e.g. { name: "Foo" }
          # @return [ActiveRecord::Relation]
          def filter(scope, assoc, filter_type, fields)
            apply_where(scope.joins(assoc), assoc, filter_type, fields)
          end

          # Applies only the WHERE clause without adding a JOIN.
          #
          # Used by Filter::Rules when the JOIN has already been applied once
          # for the association (deduplication).
          #
          # @param scope  [ActiveRecord::Relation] must already have the JOIN
          # @param assoc  [Symbol]
          # @param filter_type [Symbol]
          # @param fields [Hash]
          # @return [ActiveRecord::Relation]
          def apply_where(scope, assoc, filter_type, fields)
            table = association_table_name(assoc)

            fields.reduce(scope) do |scoped, (field, value)|
              param_key = :"#{assoc}__#{field}"
              sql       = build_sql(filter_type, table, field, param_key)

              scoped.where(sql, { param_key => prepare_value(filter_type, value) })
            end
          end

          private

          attr_reader :context

          # Builds the SQL fragment for the given filter type.
          #
          # Uses a unique param_key (assoc__field) to avoid naming collisions
          # when filtering the same field on different associations.
          #
          # @return [String]
          def build_sql(filter_type, table, field, param_key)
            format(SQL_TEMPLATES[filter_type], table: table, field: field, key: param_key)
          end

          # Transforms the raw value for the given filter type.
          #
          # @return [Object]
          def prepare_value(filter_type, value)
            case filter_type
            when :like then "%#{value}%"
            when :in   then value.to_s.split(",").map(&:strip)
            else            value
            end
          end

          # Resolves the table name from the AR reflection.
          #
          # @return [String, nil]
          def association_table_name(assoc)
            context.model_class.reflect_on_association(assoc)&.klass&.table_name
          end
        end
      end
    end
  end
end
