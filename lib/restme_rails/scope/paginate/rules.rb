# frozen_string_literal: true

module RestmeRails
  module Scope
    module Paginate
      # Provides pagination capabilities for scoped queries.
      #
      # Supported query parameters:
      #
      #   ?page=2
      #   ?per_page=20
      #
      # Configuration defaults:
      #
      # - RestmeRails::Configuration.pagination_default_page
      # - RestmeRails::Configuration.pagination_default_per_page
      # - RestmeRails::Configuration.pagination_max_per_page
      #
      # Pagination is applied using:
      # - limit
      # - offset
      #
      module Rules
        # Applies limit and offset to the given scope.
        #
        # @param user_scope [ActiveRecord::Relation]
        # @return [ActiveRecord::Relation]
        def paginable_scope(user_scope)
          user_scope.limit(per_page).offset(paginate_offset)
        end

        # Returns current page number.
        #
        # Defaults to configured default page if not provided.
        #
        # @return [Integer]
        def page_no
          params[:page]&.to_i || ::RestmeRails::Configuration.pagination_default_page
        end

        # Calculates total number of pages.
        #
        # @param user_scope [ActiveRecord::Relation]
        # @return [Integer]
        def pages(user_scope)
          (total_items(user_scope) / per_page.to_f).ceil
        end

        # Returns total number of items in the unpaginated scope.
        #
        # Memoized per request.
        #
        # @param user_scope [ActiveRecord::Relation]
        # @return [Integer]
        def total_items(user_scope)
          @total_items ||= user_scope.size
        end

        # Returns number of items per page.
        #
        # Defaults to configured default if not provided.
        #
        # @return [Integer]
        def per_page
          params[:per_page]&.to_i || ::RestmeRails::Configuration.pagination_default_per_page
        end

        # Calculates offset based on page and per_page.
        #
        # Formula:
        #   (page - 1) * per_page
        #
        # @return [Integer]
        def paginate_offset
          (page_no - 1) * per_page
        end

        # Validates per_page against maximum allowed value.
        #
        # If per_page exceeds:
        #   pagination_max_per_page
        #
        # Registers:
        # - Error message
        # - HTTP status :bad_request
        #
        # @return [Boolean, nil]
        def per_page_errors
          return if per_page <= ::RestmeRails::Configuration.pagination_max_per_page

          add_per_page_errors

          true
        end

        def add_per_page_errors
          restme_scope_errors(
            {
              message: "Invalid per page value",
              body: {
                per_page_max_value: ::RestmeRails::Configuration.pagination_max_per_page
              }
            }
          )

          restme_scope_status(:bad_request)
        end
      end
    end
  end
end
