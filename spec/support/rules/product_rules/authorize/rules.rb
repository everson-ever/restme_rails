# frozen_string_literal: true

module ProductRules
  module Authorize
    class Rules
      ALLOWED_ROLES_ACTIONS = {
        index: %i[super_admin client manager],
        show: %i[super_admin client manager],
        create: %i[super_admin client manager],
        update: %i[super_admin client manager other]
      }.freeze
    end
  end
end
