# frozen_string_literal: true

require_relative "types/equal_filterable"
require_relative "types/like_filterable"
require_relative "types/bigger_than_filterable"
require_relative "types/less_than_filterable"
require_relative "types/bigger_than_or_equal_to_filterable"
require_relative "types/less_than_or_equal_to_filterable"
require_relative "types/in_filterable"

module RestmeRails
  module Scope
    module Filter
      # Provides dynamic filtering capabilities based on query parameters.
      #
      # Supported filter pattern:
      #
      #   GET /products?name_equal=foo
      #   GET /products?price_bigger_than=10
      #   GET /products?email_like=gmail
      #
      # Pattern:
      #   "#{field}_#{filter_type}"
      #
      # Supported filter types:
      #   - equal
      #   - like
      #   - bigger_than
      #   - less_than
      #   - bigger_than_or_equal_to
      #   - less_than_or_equal_to
      #   - in
      #
      # Only fields declared in `klass::FILTERABLE_FIELDS` are allowed.
      # :id is always allowed.
      #
      module Rules
        include ::Scope::Filter::Types::InFilterable
        include ::Scope::Filter::Types::LessThanOrEqualToFilterable
        include ::Scope::Filter::Types::BiggerThanOrEqualToFilterable
        include ::Scope::Filter::Types::LessThanFilterable
        include ::Scope::Filter::Types::BiggerThanFilterable
        include ::Scope::Filter::Types::LikeFilterable
        include ::Scope::Filter::Types::EqualFilterable

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

        private

        # Applies filtering pipeline to the given scope.
        #
        # Flow:
        # 1. Validates request method
        # 2. Validates allowed fields
        # 3. Applies filter types sequentially
        # 4. Returns none_scope if record not found by id
        #
        # @param user_scope [ActiveRecord::Relation]
        # @return [ActiveRecord::Relation]
        def filterable_scope(user_scope)
          @user_scope = user_scope

          return user_scope unless filterable_scope?
          return none_scope if record_not_found_errors

          processed_scope
        end

        # Executes all supported filter types in sequence.
        #
        # @return [ActiveRecord::Relation]
        def processed_scope
          @processed_scope ||= begin
            next_scope = where_equal(@user_scope)
            next_scope = where_like(next_scope)
            next_scope = where_bigger_than(next_scope)
            next_scope = where_less_than(next_scope)
            next_scope = where_bigger_than_or_equal_to(next_scope)
            next_scope = where_less_than_or_equal_to(next_scope)
            where_in(next_scope)
          end
        end

        # Determines allowed filter fields based on:
        # - Query parameters
        # - Supported filter types
        # - Model FILTERABLE_FIELDS constant
        #
        # @return [Array<Symbol>]
        def allowed_fields
          @allowed_fields ||= controller_params_filters_fields.map do |param_key|
            filter_type = FILTERS_TYPES.find do |type|
              param_key.to_s.end_with?(type.to_s)
            end

            next unless filter_type

            record_field = param_key.to_s.gsub("_#{filter_type}", "").to_sym
            next unless filterable_fields.include?(record_field)

            send(:"add_#{filter_type}_field", record_field)
          end.compact.flatten
        end

        def params_filters
          @params_filters ||= {}
        end

        # Returns filterable fields defined in model.
        #
        # Reads:
        #   klass::FILTERABLE_FIELDS
        #
        # :id is always allowed.
        #
        # @return [Array<Symbol>]
        def filterable_fields
          @filterable_fields ||= Array.new(klass::FILTERABLE_FIELDS).push(ID)
        rescue StandardError
          [ID]
        end

        # Determines if filtering should be applied.
        #
        # Only applies for GET requests with filter params.
        #
        # @return [Boolean]
        def filterable_scope?
          request.get? && controller_params_filters_fields.present?
        end

        # Automatically inserts id_equal filter if :id param is present.
        def try_insert_id_equal
          return if params[:id].blank?

          controller_params_filters_fields.push(:id_equal)
        end

        # Registers error for unallowed filter fields.
        #
        # @return [Boolean, nil]
        def unallowed_filter_fields_errors
          try_insert_id_equal

          return unless unallowed_fields_to_filter.present?

          restme_scope_errors(
            {
              message: "Unknown Filter Fields",
              body: unallowed_fields_to_filter
            }
          )

          restme_scope_status(:bad_request)

          true
        end

        # Registers error if filtering by id returns no record.
        #
        # @return [Boolean, nil]
        def record_not_found_errors
          return if params[:id].blank? || processed_scope.exists?

          restme_scope_errors(
            {
              message: "Record not found",
              body: { id: params[:id] }
            }
          )

          restme_scope_status(:not_found)

          true
        end

        # Returns filter fields that are not allowed.
        #
        # @return [Array<Symbol>]
        def unallowed_fields_to_filter
          @unallowed_fields_to_filter ||= controller_params_filters_fields - allowed_fields
        end

        # Extracts filter parameters from query string.
        #
        # Matches keys ending with supported filter types.
        #
        # @return [Array<Symbol>]
        def controller_params_filters_fields
          @controller_params_filters_fields ||= controller_query_params.keys.select do |key|
            FILTERS_TYPES.any? { |filter| key.to_s.end_with?(filter.to_s) }
          end
        end
      end
    end
  end
end
