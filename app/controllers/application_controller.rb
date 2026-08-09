class ApplicationController < ActionController::API
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate!

  # Note: Rails checks rescue_from handlers most-recently-declared first,
  # so the generic Storage::Error handler is declared before the more
  # specific ConfigurationError / NotFound handlers.
  rescue_from Storage::Error do |e|
    logger.error("storage backend error: #{e.message}")
    render json: { error: "storage backend error" }, status: :bad_gateway
  end

  rescue_from Storage::ConfigurationError do |e|
    render json: { error: e.message }, status: :internal_server_error
  end

  rescue_from Storage::NotFound, ActiveRecord::RecordNotFound do |e|
    render json: { error: "not found" }, status: :not_found
  end

  private

  # Bearer token authentication. The accepted token is configured via
  # SIMPLE_DRIVE_TOKEN; comparison is constant-time.
  def authenticate!
    expected = Rails.configuration.x.auth_token

    authenticated = expected.present? && authenticate_with_http_token do |token, _options|
      ActiveSupport::SecurityUtils.secure_compare(token, expected)
    end

    return if authenticated

    response.headers["WWW-Authenticate"] = 'Bearer realm="simple-drive"'
    render json: { error: "unauthorized" }, status: :unauthorized
  end
end
