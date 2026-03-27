# frozen_string_literal: true

class EstablishmentsController
  include RestmeRails

  restme_authorize_action :index, %i[super_admin client manager]
  restme_authorize_action :show,  %i[super_admin client manager]

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
  rescue RestmeRails::NotAuthorizedError => e
    authorization_error(e)
  end

  def show
    @action_name = "show"

    restme_authorize!

    {
      body: model_scope_object.as_json,
      status: restme_scope_status
    }
  rescue RestmeRails::NotAuthorizedError => e
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
