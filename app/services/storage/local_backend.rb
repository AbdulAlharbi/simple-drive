module Storage
  # Filesystem backend. The only configuration is the root directory
  # (LOCAL_STORAGE_PATH). Files are named by the SHA-256 of the blob id
  # and sharded two levels deep to keep directories small; writes go to
  # a temp file first and are renamed into place so readers never see a
  # partial blob.
  class LocalBackend < BaseBackend
    def initialize(root:)
      raise ConfigurationError, "local backend: storage path not configured" if root.blank?
      @root = Pathname.new(root)
    end

    def put(id, bytes)
      path = path_for(id)
      path.dirname.mkpath
      tmp = path.sub_ext(".tmp-#{Process.pid}-#{SecureRandom.hex(4)}")
      tmp.binwrite(bytes)
      File.rename(tmp, path)
    ensure
      tmp&.unlink if tmp&.exist?
    end

    def get(id)
      path = path_for(id)
      raise NotFound, "blob #{id.inspect} not found in local storage" unless path.exist?
      path.binread
    end

    private

    def path_for(id)
      digest = digest_name(id)
      @root.join(digest[0, 2], digest[2, 2], digest)
    end
  end
end
