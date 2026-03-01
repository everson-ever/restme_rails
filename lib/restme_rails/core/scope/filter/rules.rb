# frozen_string_literal: true

require_relative "types/equal_filterable"
require_relative "types/like_filterable"
require_relative "types/bigger_than_filterable"
require_relative "types/less_than_filterable"
require_relative "types/bigger_than_or_equal_to_filterable"
require_relative "types/less_than_or_equal_to_filterable"
require_relative "types/in_filterable"

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
        #
        # Format:
        #
        #   "#{field}_#{filter_type}"
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

          attr_reader :context, :scope_error_instance, :filters_serialized

          # @param context [RestmeRails::Context]
          # @param scope_error_instance [ScopeErrorHandler]
          def initialize(context:, scope_error_instance:)
            @context = context
            @scope_error_instance = scope_error_instance
            @filters_serialized = {}

            # Pre-serialize allowed filter fields
            serialized_allowed_fields
          end

          # Applies filtering pipeline to the given ActiveRecord scope.
          #
          # @param user_scope [ActiveRecord::Relation]
          # @return [ActiveRecord::Relation]
          def filterable_scope(user_scope)
            @user_scope = user_scope

            return user_scope unless filterable_scope?
            return context.model_class.none if record_not_found_errors

            processed_scope
          end

          # Registers error for unknown filter fields.
          #
          # @return [Boolean, nil]
          def unallowed_filter_fields_errors
            try_insert_id_equal

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

          # Applies all filter types sequentially.
          #
          # Order matters.
          #
          # @return [ActiveRecord::Relation]
          def processed_scope
            @processed_scope ||= begin
              next_scope = equal_instance.where_equal(@user_scope)
              next_scope = like_instance.where_like(next_scope)
              next_scope = bigger_than_instance.where_bigger_than(next_scope)
              next_scope = less_than_instance.where_less_than(next_scope)
              next_scope = bigger_than_or_equal_to_instance.where_bigger_than_or_equal_to(next_scope)
              next_scope = less_than_or_equal_to_instance.where_less_than_or_equal_to(next_scope)
              in_filter_instance.where_in(next_scope)
            end
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
            param_value = context.query_params[param_key]

            filters_serialized[filter_type] ||= {}
            filters_serialized[filter_type][record_field] = param_value
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
          # Only applies to GET requests with filter params.
          #
          # @return [Boolean]
          def filterable_scope?
            context.request.get? && controller_params_filters_fields.present?
          end

          # Automatically injects id_equal filter if :id param exists.
          def try_insert_id_equal
            return if context.params[:id].blank?

            controller_params_filters_fields.push(:id_equal)
          end

          # Adds 404 error if id_equal filter returns no records.
          #
          # @return [Boolean, nil]
          def record_not_found_errors
            return if context.query_params[:id_equal].blank?
            return if processed_scope.exists?

            scope_error_instance.add_error(
              {
                message: "Record not found",
                body: { id: context.query_params[:id_equal] }
              }
            )

            scope_error_instance.add_status(:not_found)

            true
          end

          # Returns filter fields that were provided but not allowed.
          #
          # @return [Array<Symbol>]
          def unserialized_allowed_fields_to_filter
            @unserialized_allowed_fields_to_filter ||=
              controller_params_filters_fields - serialized_allowed_fields
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
          # Filter Type Instances (Lazy)
          # ------------------------------------------------------------

          def in_filter_instance
            @in_filter_instance ||= Types::InFilterable
                                    .new(context: context, filters_serialized: @filters_serialized)
          end

          def less_than_or_equal_to_instance
            @less_than_or_equal_to_instance ||= Types::LessThanOrEqualToFilterable
                                                .new(context: context, filters_serialized: @filters_serialized)
          end

          def bigger_than_or_equal_to_instance
            @bigger_than_or_equal_to_instance ||= Types::BiggerThanOrEqualToFilterable
                                                  .new(context: context, filters_serialized: @filters_serialized)
          end

          def less_than_instance
            @less_than_instance ||= Types::LessThanFilterable
                                    .new(context: context, filters_serialized: @filters_serialized)
          end

          def bigger_than_instance
            @bigger_than_instance ||= Types::BiggerThanFilterable
                                      .new(context: context, filters_serialized: @filters_serialized)
          end

          def like_instance
            @like_instance ||= Types::LikeFilterable
                               .new(context: context, filters_serialized: @filters_serialized)
          end

          def equal_instance
            @equal_instance ||= Types::EqualFilterable
                                .new(context: context, filters_serialized: @filters_serialized)
          end
        end
      end
    end
  end
end
