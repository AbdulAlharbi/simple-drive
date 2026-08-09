module Storage
  # Database backend: payload bytes live in the blob_contents table,
  # which is separate from the blobs metadata table by design.
  class DatabaseBackend < BaseBackend
    def put(id, bytes)
      BlobContent.create!(blob_id: id, data: bytes)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      raise Error, "database backend: #{e.message}"
    end

    def get(id)
      record = BlobContent.find_by(blob_id: id) or
        raise NotFound, "blob #{id.inspect} not found in database storage"
      record.data.to_s.b
    end
  end
end
