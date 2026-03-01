# frozen_string_literal: true

class ProductsController
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

  def show
    @action_name = "show"

    restme_authorize!

    {
      body: model_scope_object.as_json,
      status: restme_scope_status
    }
  rescue RestmeRails::Core::Authorize::Rules::NotAuthorizedError => e
    authorization_error(e)
  end

  def create(restme_custom_params: {})
    @action_name = "create"

    restme_authorize!

    {
      body: restme_create(restme_create_custom_params: restme_custom_params),
      status: restme_create_status
    }
  rescue RestmeRails::Core::Authorize::Rules::NotAuthorizedError => e
    authorization_error(e)
  end

  def update(restme_custom_params: {})
    @action_name = "update"

    restme_authorize!

    {
      body: restme_update(restme_update_custom_params: restme_custom_params),
      status: restme_update_status
    }
  rescue RestmeRails::Core::Authorize::Rules::NotAuthorizedError => e
    authorization_error(e)
  end

  def authorization_error(error)
    {
      body: [{ body: {}, message: error.message }.as_json],
      status: :forbidden
    }
  end
end
