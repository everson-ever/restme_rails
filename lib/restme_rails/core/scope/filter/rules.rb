# frozen_string_literal: true

require_relative "filterable"
require_relative "nested_filterable"

module RestmeRails
  module Core
    module Scope
      module Filter
        # Filter::Rules
        #
        # Responsible for parsing, validating and applying dynamic
        # query filters based on request query parameters.
        #
        # ------------------------------------------------------------
        # Supported Pattern
        # ------------------------------------------------------------
        #
        #   GET /products?name_equal=foo
        #   GET /products?price_bigger_than=10
        #   GET /products?email_like=gmail
        #   GET /products?establishment[name_equal]=foo
        #
        # Format:
        #
        #   "#{field}_#{filter_type}"
        #   "#{association}[#{field}_#{filter_type}]"
        #
        # ------------------------------------------------------------
        # Supported Filter Types
        # ------------------------------------------------------------
        #
        #   :equal
        #   :like
        #   :bigger_than
        #   :less_than
        #   :bigger_than_or_equal_to
        #   :less_than_or_equal_to
        #   :in
        #
        # ------------------------------------------------------------
        # Security Model
        # ------------------------------------------------------------
        #
        # Only fields declared in:
        #
        #   Model::FILTERABLE_FIELDS
        #   Model::NESTED_FILTERABLE_FIELDS
        #
        # are allowed.
        #
        # The :id field is always allowed.
        #
        # ------------------------------------------------------------
        # Execution Flow
        # ------------------------------------------------------------
        #
        # 1. Detect filter parameters
        # 2. Validate allowed fields
        # 3. Serialize filter data
        # 4. Apply filter pipeline
        # 5. Handle record-not-found edge cases
        #
        class Rules
          ID = :id

          FILTERS_TYPES = %i[
            equal
            like
            bigger_than
            less_than
            bigger_than_or_equal_to
            less_than_or_equal_to
            in
          ].freeze

          attr_reader :context, :scope_error_instance, :filters_serialized, :nested_filters_serialized, :scope

          # @param context [RestmeRails::Context]
          # @param scope_error_instance [ScopeErrorHandler]
          def initialize(context:, scope_error_instance:)
            @context = context
            @scope_error_instance = scope_error_instance
            @filters_serialized = {}
            @nested_filters_serialized = {}

            # Pre insert id key when show action
            insert_id_key_on_show_actions

            # Pre-serialize allowed filter fields (direct and nested)
            serialized_allowed_fields
            serialize_nested_filters
          end

          # Applies filtering pipeline to the given ActiveRecord scope.
          #
          # @param user_scope [ActiveRecord::Relation]
          # @return [ActiveRecord::Relation]
          def process(user_scope)
            @scope = user_scope

            return @scope unless filterable_scope?

            @scope = processed_scope

            record_not_found_error! unless processed_scope.exists?

            @scope
          end

          # Registers error for unknown filter fields.
          #
          # @return [Boolean, nil]
          def errors
            return unless unserialized_allowed_fields_to_filter.present?

            scope_error_instance.add_error(
              {
                message: "Unknown Filter Fields",
                body: unserialized_allowed_fields_to_filter
              }
            )

            scope_error_instance.add_status(:bad_request)

            true
          end

          private

          # ------------------------------------------------------------
          # Filter Pipeline
          # ------------------------------------------------------------

          # Applies the filter types needed.
          #
          # Order matters.
          #
          # @return [ActiveRecord::Relation]
          def processed_scope
            @processed_scope ||= begin
              FILTERS_TYPES.each do |filter_type|
                next unless @filters_serialized[filter_type]

                @scope = filterable_instance.filter(@scope, filter_type, @filters_serialized[filter_type])
              end

              apply_nested_filters

              @scope
            end
          end

          # Applies nested association filters from @nested_filters_serialized.
          #
          # Each association is joined exactly once to avoid duplicate JOINs
          # when the same association is filtered with multiple filter types.
          #
          # .distinct is added only for collection associations (has_many /
          # has_and_belongs_to_many) where the JOIN would produce duplicate rows.
          def apply_nested_filters
            unique_nested_assocs.each do |assoc|
              @scope = @scope.joins(assoc)
              @scope = @scope.distinct if many_association?(assoc)
            end

            @nested_filters_serialized.each do |filter_type, assoc_fields|
              assoc_fields.each do |assoc, fields|
                @scope = nested_filterable_instance.apply_where(@scope, assoc, filter_type, fields)
              end
            end
          end

          # Unique associations that need to be joined.
          #
          # @return [Array<Symbol>]
          def unique_nested_assocs
            @nested_filters_serialized.values.flat_map(&:keys).uniq
          end

          # Returns true for has_many / habtm associations (collection).
          #
          # @return [Boolean]
          def many_association?(assoc)
            context.model_class.reflect_on_association(assoc)&.collection?
          end

          # ------------------------------------------------------------
          # Filter Serialization
          # ------------------------------------------------------------

          # Serializes only allowed filter parameters.
          #
          # @return [Array<Symbol>]
          def serialized_allowed_fields
            @serialized_allowed_fields ||= controller_params_filters_fields.map do |param_key|
              filter_type = extract_filter_type(param_key)
              next unless filter_type

              record_field = param_key.to_s.gsub("_#{filter_type}", "").to_sym
              next unless filterable_fields.include?(record_field)

              add_serialized_field(filter_type, param_key, record_field)

              param_key
            end.compact.flatten
          end

          def extract_filter_type(param_key)
            FILTERS_TYPES.find do |type|
              param_key.to_s.end_with?(type.to_s)
            end
          end

          def add_serialized_field(filter_type, param_key, record_field)
            param_value = context.query_params[param_key] || context.params[record_field]

            filters_serialized[filter_type] ||= {}
            filters_serialized[filter_type][record_field] = param_value
          end

          # Populates @nested_filters_serialized from hash-style params.
          #
          # Reads params in the format: ?association[field_filter_type]=value
          # e.g. ?establishment[name_equal]=foo
          #
          # Only serializes fields declared in NESTED_FILTERABLE_FIELDS.
          def serialize_nested_filters
            nested_filterable_fields.each do |assoc, allowed_fields|
              assoc_params = context.query_params[assoc]
              next unless assoc_params.is_a?(Hash)

              serialize_nested_assoc_filters(assoc, allowed_fields, assoc_params)
            end
          end

          def serialize_nested_assoc_filters(assoc, allowed_fields, assoc_params)
            assoc_params.each do |sub_key, value|
              filter_type = extract_filter_type(sub_key)
              next unless filter_type

              field = sub_key.to_s.gsub(/_#{filter_type}$/, "").to_sym
              next unless allowed_fields.include?(field)

              add_nested_serialized_field(filter_type, assoc, field, value)
            end
          end

          def add_nested_serialized_field(filter_type, assoc, field, value)
            @nested_filters_serialized[filter_type] ||= {}
            @nested_filters_serialized[filter_type][assoc] ||= {}
            @nested_filters_serialized[filter_type][assoc][field] = value
          end

          # Detects hash params that look like nested filters but are not allowed.
          #
          # A param is considered a nested filter candidate when at least one of its
          # sub-keys ends with a known filter type suffix.
          #
          # @return [Array<Symbol>]
          def unserialized_nested_params
            @unserialized_nested_params ||= [].tap do |unallowed|
              context.query_params.each do |key, value|
                next unless value.is_a?(Hash)

                collect_unallowed_nested(key.to_sym, value, unallowed)
              end
            end
          end

          def collect_unallowed_nested(assoc, assoc_params, unallowed)
            allowed_fields = nested_filterable_fields[assoc]

            assoc_params.each_key do |sub_key|
              filter_type = extract_filter_type(sub_key)
              next unless filter_type

              field = sub_key.to_s.gsub(/_#{filter_type}$/, "").to_sym
              unallowed << :"#{assoc}[#{sub_key}]" unless allowed_fields&.include?(field)
            end
          end

          # Returns nested filterable fields declared in the model.
          #
          # @return [Hash]
          def nested_filterable_fields
            @nested_filterable_fields ||= context.model_class::NESTED_FILTERABLE_FIELDS
          rescue StandardError
            {}
          end

          # ------------------------------------------------------------
          # Validation & Security
          # ------------------------------------------------------------

          # Returns filterable fields declared in model.
          #
          # @return [Array<Symbol>]
          def filterable_fields
            @filterable_fields ||= Array
                                   .new(context.model_class::FILTERABLE_FIELDS)
                                   .push(ID)
          rescue StandardError
            [ID]
          end

          # Determines whether filtering should run.
          #
          # Only applies to GET requests with filter params (flat or nested hash).
          #
          # @return [Boolean]
          def filterable_scope?
            context.request.get? &&
              (controller_params_filters_fields.present? || @nested_filters_serialized.any?)
          end

          # Automatically injects id_equal filter if :id param exists.
          def insert_id_key_on_show_actions
            return unless show_action?

            controller_params_filters_fields.push(:id_equal)
          end

          def show_action?
            context.params[:id].present?
          end

          # @raise [RecordNotFoundError] if record is not found
          #
          # @return [void]
          def record_not_found_error!
            return unless show_action?

            raise RestmeRails::RecordNotFoundError, "Record not found: ID #{context.params[:id]}"
          end

          # Returns filter fields that were provided but not allowed.
          #
          # Combines unrecognized flat fields and unrecognized nested params.
          #
          # @return [Array<Symbol>]
          def unserialized_allowed_fields_to_filter
            @unserialized_allowed_fields_to_filter ||=
              (controller_params_filters_fields - serialized_allowed_fields) + unserialized_nested_params
          end

          # Extracts valid filter params from query string.
          #
          # @return [Array<Symbol>]
          def controller_params_filters_fields
            @controller_params_filters_fields ||= context.query_params.keys.select do |key|
              FILTERS_TYPES.any? { |filter| key.to_s.end_with?(filter.to_s) }
            end
          end

          # ------------------------------------------------------------
          # Filter Instances (Lazy)
          # ------------------------------------------------------------

          def filterable_instance
            @filterable_instance ||= Filterable.new(context: context)
          end

          def nested_filterable_instance
            @nested_filterable_instance ||= NestedFilterable.new(context: context)
          end
        end
      end
    end
  end
end
