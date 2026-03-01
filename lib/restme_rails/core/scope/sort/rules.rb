# frozen_string_literal: true

module RestmeRails
  module Core
    module Scope
      module Sort
        # Provides sorting capabilities based on query string parameters.
        #
        # Expected query format:
        #
        #   GET /products?name_sort=asc&price_sort=desc
        #
        # Pattern:
        #   "#{field}_sort" => "asc" | "desc"
        #
        # Rules:
        #
        # - Sorting is applied only for GET requests.
        # - Direction defaults to "asc" if invalid.
        # - Only fields declared in `klass::SORTABLE_FIELDS` are allowed.
        # - :id is always allowed.
        #
        class Rules
          ID = :id
          SORT_KEY = "sort"
          SORTABLE_TYPES = %w[asc desc].freeze

          attr_reader :context, :scope_error_instance

          def initialize(context:, scope_error_instance:)
            @context = context
            @scope_error_instance = scope_error_instance
          end

          # Applies ordering to the given scope if sorting is valid.
          #
          # @param user_scope [ActiveRecord::Relation]
          # @return [ActiveRecord::Relation]
          def sortable_scope(user_scope)
            return user_scope unless sortable_scope?

            user_scope.order(serialize_sort_params)
          end

          # Registers error if unknown sortable fields are detected.
          #
          # Sets:
          # - Error message
          # - HTTP status :bad_request
          #
          # @return [Boolean, nil]
          def unknown_sortable_fields_errors
            return unless unknown_sortable_fields.present?

            scope_error_instance.add_error(
              {
                message: "Unknown Sort",
                body: unknown_sortable_fields
              }
            )

            scope_error_instance.add_status(:bad_request)

            true
          end

          private

          # Determines whether sorting should be applied.
          #
          # Sorting is applied only if:
          # - HTTP method is GET
          # - At least one sortable field is present
          #
          # @return [Boolean]
          def sortable_scope?
            context.request.get? && controller_params_sortable_fields.present?
          end

          # Converts query parameters into an ActiveRecord-compatible
          # order structure.
          #
          # Example:
          #   { "name_sort" => "asc" }
          # becomes:
          #   { name: "asc" }
          #
          # Invalid directions default to "asc".
          #
          # @return [Array<Hash>]
          def serialize_sort_params
            @serialize_sort_params ||= controller_params_sortable_fields.map do |key, value|
              key = key.to_s.gsub("_#{SORT_KEY}", "")

              value = "asc" unless SORTABLE_TYPES.include?(value&.downcase)

              { key.to_sym => value&.downcase }
            end
          end

          # Extracts sortable parameters from query string.
          #
          # Only keys ending with "_sort" are considered.
          #
          # @return [Hash]
          def controller_params_sortable_fields
            @controller_params_sortable_fields ||= context.query_params.select do |key, _|
              key.to_s.end_with?(SORT_KEY)
            end
          end

          # Returns fields requested for sorting that are not allowed.
          #
          # @return [Array<Symbol>]
          def unknown_sortable_fields
            @unknown_sortable_fields ||=
              serialize_sort_params.map { |sort_param| sort_param.first.first } - sortable_fields
          end

          # Returns allowed sortable fields.
          #
          # Reads from:
          #   klass::SORTABLE_FIELDS
          #
          # :id is always allowed.
          #
          # If constant is not defined, defaults to [:id].
          #
          # @return [Array<Symbol>]
          def sortable_fields
            @sortable_fields ||=
              if context.model_class.const_defined?(:SORTABLE_FIELDS)
                Array.new(context.model_class::SORTABLE_FIELDS).push(ID)
              else
                [ID]
              end
          end
        end
      end
    end
  end
end
