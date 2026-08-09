# Metadata record for a stored blob. The payload itself lives in whichever
# Storage backend was active when the blob was created (recorded in
# #backend so previously stored blobs stay retrievable after the service
# is reconfigured).
class Blob < ApplicationRecord
  validates :blob_id, presence: true, uniqueness: true
  validates :size, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :backend, presence: true

  def storage
    Storage.backend(backend)
  end
end
