# frozen_string_literal: true

module ProductRules
  module Create
    class Rules
      RESTME_CREATE_ACTIONS_RULES = %i[create].freeze

      def initialize(temp_record, current_user, controller_params = {})
        @temp_record = temp_record
        @current_user = current_user
        @controller_params = controller_params
      end

      def create_super_admin_scope?
        true
      end

      def create_manager_scope?
        true
      end

      def create_client_scope?
        false
      end
    end
  end
end
