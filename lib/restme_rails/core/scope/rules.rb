# frozen_string_literal: true

require_relative "filter/rules"
require_relative "sort/rules"
require_relative "paginate/rules"
require_relative "field/rules"
require_relative "pipeline"
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
        attr_reader :context, :scope_error_instance

        # Ordered list of rule processors used to build the final scope pipeline.
        #
        # The order of these processors is critical because each step
        # receives the result of the previous one.
        #
        # Pipeline order:
        #
        # 1. Filter
        # 2. Sort
        # 3. Paginate
        # 4. Field selection
        #
        # Changing this order may break expected query behavior.
        #
        # @return [Array<Symbol>]
        PIPELINE_STEPS = [
          {
            identifier: :filter_rules,
            klass: ::RestmeRails::Core::Scope::Filter::Rules
          },
          {
            identifier: :sorte_rules,
            klass: ::RestmeRails::Core::Scope::Sort::Rules
          },
          {
            identifier: :paginate_rules,
            klass: ::RestmeRails::Core::Scope::Paginate::Rules
          },
          {
            identifier: :field_rules,
            klass: ::RestmeRails::Core::Scope::Field::Rules
          }
        ].freeze

        def initialize(context:)
          @context = context
          @scope_error_instance = RestmeRails::ScopeError.new

          check_scope_errors
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
          @pagination_response ||= (pagination_response_object if scope_errors.blank?)
        end

        # Returns a single scoped object (first record).
        #
        # Used for show-like behavior.
        #
        # If any scope error occurs, returns the error payload instead.
        #
        # @return [ActiveRecord::Base, Hash, nil]
        def model_scope_object
          @model_scope_object ||= (model_scope&.first if scope_errors.blank?)
        end

        # Returns the HTTP-like status derived from scope errors.
        #
        # Delegates to ScopeError instance.
        #
        # Example:
        #   200 -> success
        #   400 -> invalid query parameters
        #   403 -> forbidden access
        #
        # @return [Integer]
        def scope_status
          scope_error_instance.scope_status
        end

        # Returns the aggregated scope errors collected during rule execution.
        #
        # Errors may originate from:
        #
        # - filtering
        # - sorting
        # - pagination
        # - field selection
        #
        # @return [Array<Hash>]
        def scope_errors
          scope_error_instance.scope_errors
        end

        private

        # Builds paginated response structure.
        def pagination_response_object
          {
            objects: model_scope,
            pagination: pagination
          }
        end

        # Executes all error-checking methods and aggregates errors.
        #
        # @return [Array, nil]
        def check_scope_errors
          @check_scope_errors ||= pipeline.check_scope_errors
        end

        # Final composed ActiveRecord::Relation.
        #
        # @return [ActiveRecord::Relation]
        def model_scope
          @model_scope ||= final_scope
        end

        # Pagination metadata.
        #
        # @return [Hash]
        def pagination
          {
            page: @paginate_rules.page_no,
            pages: @paginate_rules.pages(@filter_rules.scope),
            total_items: @paginate_rules.total_items(@filter_rules.scope)
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
        def final_scope
          @final_scope ||= pipeline.call(user_scope)
        end

        def pipeline
          @pipeline ||= begin
            steps = PIPELINE_STEPS.map do |pipeline|
              instance = pipeline[:klass].new(context: context, scope_error_instance: scope_error_instance)

              instance_variable_name = pipeline[:identifier]

              instance_variable_set(:"@#{instance_variable_name}", instance)
            end

            Pipeline.new(steps)
          end
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
            methods_scopes.select do |method_scope|
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
        def methods_scopes
          @methods_scopes ||= context.current_user_roles.map do |role|
            "#{role}_scope"
          end
        end

        # Lazily instantiates the dynamic Scope Rules class.
        #
        # The class is resolved using the Restme convention system
        # and initialized with:
        #
        #   (model_class, current_user, params)
        #
        # This class is responsible for defining role-based scopes,
        # such as:
        #
        #   admin_scope
        #   manager_scope
        #
        # @return [Object, nil]
        def scope_rules_class_instance
          @scope_rules_class_instance ||= scope_rules_class&.new(
            context.model_class,
            context.current_user,
            context.params
          )
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
          @scope_rules_class ||=
            RestmeRails::RulesFind.new(klass: context.model_class, rule_context: "Scope").rule_class
        end
      end
    end
  end
end
