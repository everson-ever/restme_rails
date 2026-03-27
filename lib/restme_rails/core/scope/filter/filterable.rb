# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Filter
        # Handles direct (own-table) field filtering.
        #
        # Responsible for applying WHERE clauses against the model's own
        # table for all supported filter types.
        #
        # ------------------------------------------------------------------
        # Query Param Convention
        # ------------------------------------------------------------------
        #
        # Format:
        #
        #   ?#{field}_#{filter_type}=value
        #
        # Examples:
        #
        #   ?name_equal=Foo
        #   ?name_like=oo
        #   ?price_bigger_than=10
        #   ?id_in=1,2,3
        #
        # ------------------------------------------------------------------
        # Supported Filter Types
        # ------------------------------------------------------------------
        #
        #   :equal                   → col = val
        #   :like                    → CAST(col AS TEXT) ILIKE '%val%'
        #   :bigger_than             → col > val
        #   :less_than               → col < val
        #   :bigger_than_or_equal_to → col >= val
        #   :less_than_or_equal_to   → col <= val
        #   :in                      → col IN (val1, val2, …)
        #
        # ------------------------------------------------------------------
        # Security
        # ------------------------------------------------------------------
        #
        # - Only fields declared in FILTERABLE_FIELDS (or :id) reach here.
        # - Named bind parameters prevent SQL injection.
        # - Column is always qualified with the model table name.
        #
        class Filterable
          SQL_TEMPLATES = {
            equal: "%<table>s.%<field>s = :%<field>s",
            like: "CAST(%<table>s.%<field>s AS TEXT) ILIKE :%<field>s",
            bigger_than: "%<table>s.%<field>s > :%<field>s",
            less_than: "%<table>s.%<field>s < :%<field>s",
            bigger_than_or_equal_to: "%<table>s.%<field>s >= :%<field>s",
            less_than_or_equal_to: "%<table>s.%<field>s <= :%<field>s",
            in: "%<table>s.%<field>s IN (:%<field>s)"
          }.freeze

          # @param context [RestmeRails::Context]
          def initialize(context:)
            @context = context
          end

          # Applies WHERE clauses for all fields in the given filter type.
          #
          # @param scope       [ActiveRecord::Relation]
          # @param filter_type [Symbol] e.g. :equal
          # @param fields      [Hash]  e.g. { name: "Foo", status: "active" }
          # @return [ActiveRecord::Relation]
          def filter(scope, filter_type, fields)
            table = context.model_class.table_name

            fields.reduce(scope) do |scoped, (field, value)|
              sql = format(SQL_TEMPLATES[filter_type], table: table, field: field)
              scoped.where(sql, { field => prepare_value(filter_type, value) })
            end
          end

          private

          attr_reader :context

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
        end
      end
    end
  end
end
