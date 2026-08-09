source "https://rubygems.org"

ruby ">= 3.1.0"

gem "rails", "~> 7.1"
gem "sqlite3", "~> 1.7"
gem "puma", "~> 6.0"

group :development, :test do
  gem "debug", platforms: %i[mri]
end

group :test do
  # In-process HTTP server used as a fake S3 in the backend tests
  # (webrick left Ruby's default gems in 3.0)
  gem "webrick", "~> 1.8"
end

# FTP client for the FTP storage backend (left Ruby's default gems in 3.1)
gem "net-ftp", "~> 0.3"
