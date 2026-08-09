require_relative "boot"

# Require only the frameworks this API needs (instead of rails/all).
require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"

# Load Gemfile gems when running under Bundler; otherwise the requires
# above (resolved from system gems) are sufficient.
if defined?(Bundler::ORIGINAL_ENV)
  begin
    Bundler.require(*Rails.groups)
  rescue StandardError
    nil
  end
end

module SimpleDrive
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.api_only = true

    # Storage backend configuration.
    #
    # STORAGE_BACKEND selects where blob *data* lives: s3 | database | local | ftp
    # (metadata is always tracked in the blobs table regardless of backend).
    config.x.storage.backend = ENV.fetch("STORAGE_BACKEND", "local")

    config.x.storage.local_path = ENV.fetch("LOCAL_STORAGE_PATH") { Rails.root.join("storage", "blobs").to_s }

    config.x.storage.s3 = {
      endpoint: ENV["S3_ENDPOINT"],                # e.g. https://s3.amazonaws.com or http://localhost:9000 (minio)
      region: ENV.fetch("S3_REGION", "us-east-1"),
      bucket: ENV["S3_BUCKET"],
      access_key_id: ENV["S3_ACCESS_KEY_ID"],
      secret_access_key: ENV["S3_SECRET_ACCESS_KEY"]
    }

    config.x.storage.ftp = {
      host: ENV["FTP_HOST"],
      port: Integer(ENV.fetch("FTP_PORT", 21)),
      user: ENV["FTP_USER"],
      password: ENV["FTP_PASSWORD"],
      base_dir: ENV.fetch("FTP_BASE_DIR", "simple_drive"),
      passive: ENV.fetch("FTP_PASSIVE", "true") == "true"
    }

    # Bearer token accepted by the API. See README for generation.
    config.x.auth_token = ENV["SIMPLE_DRIVE_TOKEN"]
  end
end
