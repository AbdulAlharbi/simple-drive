require "pathname" # Ruby 3.2 compat: rails/command.rb uses Pathname without requiring it
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Use Bundler when the bundle has been installed (normal development
# setup). Without a lockfile, fall back to system-installed gems -- the
# app only depends on rails, sqlite3 and the stdlib.
require "bundler/setup" if File.exist?(File.expand_path("../Gemfile.lock", __dir__))
