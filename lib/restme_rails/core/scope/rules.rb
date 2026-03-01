# frozen_string_literal: true

require_relative "filter/rules"
require_relative "sort/rules"
require_relative "paginate/rules"
require_relative "field/rules"
require_relative "../../rules_find"
require_relative "../../scope_error"

module RestmeRails
  module Core
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
      class Rules
        attr_reader :context, :scope_error_instance, :filterable_scope_response

        def initialize(context:)
          @context = context
          @scope_error_instance = RestmeRails::ScopeError.new

          any_scope_errors
        end

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
            scope_error_instance.restme_scope_errors.presence || restme_pagination_response
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
            scope_error_instance.restme_scope_errors.presence || model_scope.first
          end
        end

        def restme_scope_status
          scope_error_instance.restme_scope_status
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
          @any_scope_errors ||= begin
            [
              paginate_rules.per_page_errors,
              sort_rules.unknown_sortable_fields_errors,
              filter_rules.unallowed_filter_fields_errors,
              field_rules.unallowed_select_fields_errors,
              field_rules.unallowed_attachment_fields_errors
            ].freeze

            scope_error_instance.restme_scope_errors
          end
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
            page: paginate_rules.page_no,
            pages: paginate_rules.pages(filterable_scope_response),
            total_items: paginate_rules.total_items(filterable_scope_response)
          }
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
          @filterable_scope_response = filter_rules.filterable_scope(user_scope)
          scope = sort_rules.sortable_scope(filterable_scope_response)
          scope = paginate_rules.paginable_scope(scope)
          field_rules.fieldable_scope(scope)
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
          scopes = user_scope_methods.map { |m| scope_rules_class_instance.try(m) }

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
              scope_rules_class_instance.respond_to?(method_scope)
            end
        end

        # If no user is present, returns full dataset.
        #
        # @return [ActiveRecord::Relation, nil]
        def none_user_scope
          context.model_class.all if context.current_user.blank?
        end

        # Fallback when no role scope matches.
        #
        # @return [ActiveRecord::Relation]
        def none_scope
          context.model_class.none
        end

        # Builds scope method names from roles.
        #
        # Example:
        #   :admin -> "admin_scope"
        #
        # @return [Array<String>]
        def restme_methods_scopes
          @restme_methods_scopes ||= context.current_user_roles.map do |restme_role|
            "#{restme_role}_scope"
          end
        end

        def scope_rules_class_instance
          @scope_rules_class_instance ||= scope_rules_class&.new(context.model_class, context.current_user,
                                                                 context.params)
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
          @scope_rules_class ||= RestmeRails::RulesFind.new(klass: context.model_class,
                                                            rule_context: "Scope").rule_class
        end

        def field_rules
          @field_rules ||= ::RestmeRails::Core::Scope::Field::Rules
                           .new(context: context, scope_error_instance: scope_error_instance)
        end

        def paginate_rules
          @paginate_rules ||= ::RestmeRails::Core::Scope::Paginate::Rules
                              .new(context: context, scope_error_instance: scope_error_instance)
        end

        def sort_rules
          @sort_rules ||= ::RestmeRails::Core::Scope::Sort::Rules
                          .new(context: context, scope_error_instance: scope_error_instance)
        end

        def filter_rules
          @filter_rules ||= ::RestmeRails::Core::Scope::Filter::Rules
                            .new(context: context, scope_error_instance: scope_error_instance)
        end
      end
    end
  end
end
