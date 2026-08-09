# Payload row used exclusively by the database storage backend.
class BlobContent < ApplicationRecord
  validates :blob_id, presence: true, uniqueness: true
end
