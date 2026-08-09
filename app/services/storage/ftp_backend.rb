require "net/ftp"
require "stringio"

module Storage
  # FTP backend. Connects per operation, stores each blob as a file named
  # by the SHA-256 of its id inside base_dir. The connection factory is
  # injectable for testing.
  class FtpBackend < BaseBackend
    def initialize(host:, user:, password:, port: 21, base_dir: "simple_drive", passive: true, ftp_factory: nil)
      raise ConfigurationError, "FTP backend: FTP_HOST not configured" if host.blank?
      @host = host
      @port = port
      @user = user
      @password = password
      @base_dir = base_dir
      @passive = passive
      @ftp_factory = ftp_factory || method(:default_factory)
    end

    def put(id, bytes)
      with_ftp do |ftp|
        ensure_base_dir(ftp)
        ftp.storbinary("STOR #{remote_path(id)}", StringIO.new(bytes.b), Net::FTP::DEFAULT_BLOCKSIZE)
      end
    rescue Net::FTPError, SystemCallError => e
      raise Error, "FTP put failed: #{e.class}: #{e.message}"
    end

    def get(id)
      buffer = +""
      with_ftp do |ftp|
        ftp.retrbinary("RETR #{remote_path(id)}", Net::FTP::DEFAULT_BLOCKSIZE) { |chunk| buffer << chunk }
      end
      buffer.b
    rescue Net::FTPPermError => e
      # 550 = file unavailable
      raise NotFound, "blob #{id.inspect} not found on FTP server (#{e.message.strip})"
    rescue Net::FTPError, SystemCallError => e
      raise Error, "FTP get failed: #{e.class}: #{e.message}"
    end

    private

    def remote_path(id)
      "#{@base_dir}/#{digest_name(id)}"
    end

    def ensure_base_dir(ftp)
      ftp.mkdir(@base_dir)
    rescue Net::FTPPermError
      nil # already exists
    end

    def with_ftp
      ftp = @ftp_factory.call
      yield ftp
    ensure
      ftp&.close
    end

    def default_factory
      ftp = Net::FTP.new
      ftp.passive = @passive
      ftp.connect(@host, @port)
      ftp.login(@user, @password)
      ftp.binary = true
      ftp
    end
  end
end
