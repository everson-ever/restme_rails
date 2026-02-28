# frozen_string_literal: true

require_relative "restme_rails/version"
require_relative "restme_rails/authorize/rules"
require_relative "restme_rails/scope/rules"
require_relative "restme_rails/create/rules"
require_relative "restme_rails/update/rules"
require_relative "restme_rails/configuration"

# Defines the initialization rules for RestmeRails.
module RestmeRails
  include ::RestmeRails::Update::Rules
  include ::RestmeRails::Create::Rules
  include ::RestmeRails::Scope::Rules
  include ::RestmeRails::Authorize::Rules

  attr_reader :restme_current_user

  class << self
    def configure
      yield(Configuration)
    end
  end

  def initialize_restme
    use_current_user

    restme_authorize_response unless user_authorized?
  end

  private

  def restme_authorize_response
    render json: restme_scope_errors, status: restme_scope_status
  end

  def use_current_user
    @restme_current_user =
      try(::RestmeRails::Configuration.current_user_variable)
  end
end
