# frozen_string_literal: true

module ProductRules
  module Update
    class Rules
      RESTME_UPDATE_ACTIONS_RULES = %i[update].freeze

      def initialize(temp_record, current_user, controller_params = {})
        @temp_record = temp_record
        @current_user = current_user
        @controller_params = controller_params
      end

      def update_super_admin_scope?
        true
      end

      def update_manager_scope?
        true
      end

      def update_client_scope?
        true
      end
    end
  end
end
