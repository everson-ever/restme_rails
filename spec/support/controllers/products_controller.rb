# frozen_string_literal: true

class ProductsController
  include RestmeRails

  attr_accessor :params, :request, :current_user, :logged_user
  attr_reader :action_name

  class AuthorizationError < StandardError
    attr_reader :json, :status

    def initialize(json: {}, status: nil)
      @json = json
      @status = status

      super
    end
  end

  def initialize(current_user: nil, logged_user: nil, request: {}, params: {})
    @current_user = current_user
    @logged_user = logged_user
    @request = request
    @params = params
  end

  def index
    @action_name = "index"

    initialize_restme

    {
      body: pagination_response.as_json,
      status: restme_scope_status
    }
  rescue AuthorizationError => e
    authorization_error(e)
  end

  def show
    @action_name = "show"

    initialize_restme

    {
      body: model_scope_object.as_json,
      status: restme_scope_status
    }
  rescue AuthorizationError => e
    authorization_error(e)
  end

  def create(restme_custom_params: {})
    @action_name = "create"

    initialize_restme

    {
      body: restme_create(restme_create_custom_params: restme_custom_params),
      status: restme_create_status
    }
  rescue AuthorizationError => e
    authorization_error(e)
  end

  def update(restme_custom_params: {})
    @action_name = "update"

    initialize_restme

    {
      body: restme_update(restme_update_custom_params: restme_custom_params),
      status: restme_update_status
    }
  rescue AuthorizationError => e
    authorization_error(e)
  end

  def render(json: {}, status: nil)
    return unless status == :forbidden

    raise AuthorizationError.new(json: json, status: status)
  end

  def authorization_error(error)
    {
      body: error.json.as_json,
      status: error.status
    }
  end
end
