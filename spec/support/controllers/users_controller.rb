# frozen_string_literal: true

class UsersController
  include RestmeRails

  restme_authorize_action :index,  %i[admin manager]
  restme_authorize_action :create, %i[admin]

  attr_accessor :params, :request, :current_user
  attr_reader :action_name

  def initialize(current_user: nil, request: {}, params: {})
    @current_user = current_user
    @request = request
    @params = params
  end

  def index
    @action_name = "index"

    restme_authorize!

    { body: pagination_response.as_json, status: restme_scope_status }
  rescue RestmeRails::NotAuthorizedError => e
    { body: [{ body: {}, message: e.message }.as_json], status: :forbidden }
  end

  def create
    @action_name = "create"

    restme_authorize!

    { body: restme_create, status: restme_create_status }
  rescue RestmeRails::NotAuthorizedError => e
    { body: [{ body: {}, message: e.message }.as_json], status: :forbidden }
  end
end
