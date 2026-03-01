# frozen_string_literal: true

class SettingsController
  include RestmeRails

  attr_accessor :params, :request, :current_user, :logged_user
  attr_reader :action_name

  def initialize(current_user: nil, logged_user: nil, request: {}, params: {})
    @current_user = current_user
    @logged_user = logged_user
    @request = request
    @params = params
  end

  def index
    @action_name = "index"

    restme_authorize!

    {
      body: pagination_response.as_json,
      status: restme_scope_status
    }
  rescue RestmeRails::Core::Authorize::Rules::NotAuthorizedError => e
    authorization_error(e)
  end

  def render(json: {}, status: nil)
    return unless status == :forbidden

    raise AuthorizationError.new(json: json, status: status)
  end

  def authorization_error(error)
    {
      body: [{ body: {}, message: error.message }.as_json],
      status: :forbidden
    }
  end
end
