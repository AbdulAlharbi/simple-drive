# Storage abstraction: a single interface over multiple pluggable
# backends. Each backend implements:
#
#   put(id, bytes)  -> persists raw bytes under the opaque identifier
#   get(id)         -> returns raw bytes, or raises Storage::NotFound
#
# The active backend is chosen via configuration (STORAGE_BACKEND) and
# resolved through Storage.backend.
module Storage
  class Error < StandardError; end
  class NotFound < Error; end
  class ConfigurationError < Error; end

  BACKENDS = {
    "local"    => -> { LocalBackend.new(root: Rails.configuration.x.storage.local_path) },
    "database" => -> { DatabaseBackend.new },
    "s3"       => -> { S3Backend.from_config(Rails.configuration.x.storage.s3) },
    "ftp"      => -> { FtpBackend.new(**Rails.configuration.x.storage.ftp.symbolize_keys) }
  }.freeze

  def self.backend(name = Rails.configuration.x.storage.backend)
    builder = BACKENDS[name.to_s] or
      raise ConfigurationError, "unknown storage backend #{name.inspect} (valid: #{BACKENDS.keys.join(', ')})"
    builder.call
  end
end
