# frozen_string_literal: true

require_relative "../shared/restme_current_user_roles"
require_relative "../shared/current_model"
require_relative "../shared/controller_params"
require_relative "filter/rules"
require_relative "sort/rules"
require_relative "paginate/rules"
require_relative "field/rules"

module RestmeRails
  module Scope
    # Provides a complete query scoping pipeline for index/show actions.
    #
    # Responsibilities:
    #
    # - Role-based user scope resolution
    # - Filtering
    # - Sorting
    # - Pagination
    # - Field selection
    # - Error aggregation
    #
    # Expected convention:
    #
    # A Rules class may exist following the pattern:
    #   "#{ControllerName}Restme::Scope::Rules"
    #
    # Scope methods inside that class must follow:
    #   "#{role}_scope"
    #
    # Example:
    #   admin_scope
    #   manager_scope
    #
    # Each method must return an ActiveRecord::Relation.
    #
    module Rules
      include ::RestmeRails::Scope::Field::Rules
      include ::RestmeRails::Scope::Paginate::Rules
      include ::RestmeRails::Scope::Sort::Rules
      include ::RestmeRails::Scope::Filter::Rules
      include ::RestmeRails::Shared::ControllerParams
      include ::RestmeRails::Shared::CurrentModel
      include ::RestmeRails::Shared::RestmeCurrentUserRoles

      attr_reader :filterable_scope_response
      attr_writer :restme_scope_errors, :restme_scope_status

      # Methods that may register scope errors.
      SCOPE_ERROR_METHODS = %i[
        per_page_errors
        unknown_sortable_fields_errors
        unallowed_filter_fields_errors
        unallowed_select_fields_errors
        unallowed_attachment_fields_error
      ].freeze

      # Returns paginated response structure.
      #
      # Output:
      # {
      #   objects: [...],
      #   pagination: { page:, pages:, total_items: }
      # }
      #
      # If any scope error occurs, returns the error payload instead.
      #
      # @return [Hash]
      def pagination_response
        @pagination_response ||= begin
          prepare_model_scope
          restme_scope_errors.presence || restme_pagination_response
        end
      end

      # Returns a single scoped object (first record).
      #
      # Used for show-like behavior.
      #
      # If any scope error occurs, returns the error payload instead.
      #
      # @return [ActiveRecord::Base, Hash, nil]
      def model_scope_object
        @model_scope_object ||= begin
          prepare_model_scope
          restme_scope_errors.presence || model_scope.first
        end
      end

      private

      # Builds paginated response structure.
      def restme_pagination_response
        {
          objects: model_scope,
          pagination: pagination
        }
      end

      # Prepares model scope only if no errors are detected.
      def prepare_model_scope
        model_scope if any_scope_errors.blank?
      end

      # Executes all error-checking methods and aggregates errors.
      #
      # @return [Array, nil]
      def any_scope_errors
        SCOPE_ERROR_METHODS.each { |m| send(m) }
        restme_scope_errors
      end

      # Final composed ActiveRecord::Relation.
      #
      # @return [ActiveRecord::Relation]
      def model_scope
        @model_scope ||= custom_scope
      end

      # Pagination metadata.
      #
      # @return [Hash]
      def pagination
        {
          page: page_no,
          pages: pages(filterable_scope_response),
          total_items: total_items(filterable_scope_response)
        }
      end

      # Aggregates scope errors.
      #
      # If called with an argument, appends error.
      #
      # @return [Array]
      def restme_scope_errors(error = nil)
        @restme_scope_errors ||= []
        @restme_scope_errors << error if error.present?
        @restme_scope_errors
      end

      # Sets HTTP status for scope responses.
      #
      # Default: :ok
      #
      # @return [Symbol]
      def restme_scope_status(status = :ok)
        @restme_scope_status ||= status
      end

      # Complete query pipeline:
      #
      # 1. Resolve user scope
      # 2. Apply filtering
      # 3. Apply sorting
      # 4. Apply pagination
      # 5. Apply field selection
      #
      # @return [ActiveRecord::Relation]
      def custom_scope
        @filterable_scope_response = filterable_scope(user_scope)

        scope = sortable_scope(filterable_scope_response)
        scope = paginable_scope(scope)

        fieldable_scope(scope)
      end

      # Resolves base scope based on user roles.
      #
      # Strategy:
      #
      # - If no user: returns all records
      # - If role scope methods exist: combine them using OR
      # - If multiple scopes: ensures distinct results
      # - If no matching scope: returns none
      #
      # @return [ActiveRecord::Relation]
      def user_scope
        @user_scope ||= none_user_scope || process_user_scope || none_scope
      end

      # Executes all matching role scope methods
      # and combines them using `or`.
      #
      # @return [ActiveRecord::Relation, nil]
      def process_user_scope
        scopes = user_scope_methods.map { |m| scope_rules_class.try(m) }

        processed_scope = scopes.reduce { |combined, s| combined.or(s) }

        user_scope_methods.many? ? processed_scope&.distinct : processed_scope
      end

      # Returns valid scope methods based on user roles.
      #
      # Example:
      #   admin_scope
      #   manager_scope
      #
      # @return [Array<Symbol>]
      def user_scope_methods
        @user_scope_methods ||=
          restme_methods_scopes.select do |method_scope|
            scope_rules_class.respond_to?(method_scope)
          end
      end

      # If no user is present, returns full dataset.
      #
      # @return [ActiveRecord::Relation, nil]
      def none_user_scope
        klass.all if restme_current_user.blank?
      end

      # Fallback when no role scope matches.
      #
      # @return [ActiveRecord::Relation]
      def none_scope
        klass.none
      end

      # Builds scope method names from roles.
      #
      # Example:
      #   :admin -> "admin_scope"
      #
      # @return [Array<String>]
      def restme_methods_scopes
        @restme_methods_scopes ||= restme_current_user_roles.map do |restme_role|
          "#{restme_role}_scope"
        end
      end

      # Instantiates the Scope Rules class dynamically.
      #
      # Naming convention:
      #   "#{ControllerName}Restme::Scope::Rules"
      #
      # Initialized with:
      #   (model_class, current_user, params)
      #
      # @return [Object]
      def scope_rules_class
        "#{klass.name}Rules::Scope::Rules"
          .constantize
          .new(klass, restme_current_user, params)
      end
    end
  end
end
