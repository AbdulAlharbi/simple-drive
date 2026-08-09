module Storage
  class BaseBackend
    def put(_id, _bytes)
      raise NotImplementedError
    end

    def get(_id)
      raise NotImplementedError
    end

    private

    # Blob ids are arbitrary strings (paths, UUIDs, unicode...). Backends
    # that need a filesystem/key-safe name derive it from a digest of the
    # id rather than trying to sanitize user input.
    def digest_name(id)
      Digest::SHA256.hexdigest(id)
    end
  end
end
