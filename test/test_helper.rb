ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require "tmpdir"

# Deterministic test configuration, applied AFTER boot so it holds no
# matter when the test runner loads the application (Rails >= 7.1 boots
# the app before loading test files; older versions boot it here).
Rails.configuration.x.auth_token = "test-token"
Rails.configuration.x.storage.backend = "local"
Rails.configuration.x.storage.local_path =
  File.join(Dir.mktmpdir("simple_drive_test"), "blobs")

class ActiveSupport::TestCase
end
