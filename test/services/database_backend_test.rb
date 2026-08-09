require "test_helper"

class DatabaseBackendTest < ActiveSupport::TestCase
  setup { @backend = Storage::DatabaseBackend.new }

  test "round-trips binary data through the blob_contents table" do
    bytes = Random.bytes(512)
    @backend.put("db-id", bytes)

    assert_equal bytes, @backend.get("db-id")
    assert BlobContent.exists?(blob_id: "db-id"), "payload should live in blob_contents"
    assert_not Blob.exists?(blob_id: "db-id"), "metadata table must not be touched by the backend"
  end

  test "raises NotFound for unknown ids" do
    assert_raises(Storage::NotFound) { @backend.get("missing") }
  end

  test "rejects duplicate ids" do
    @backend.put("dup", "a")
    assert_raises(Storage::Error) { @backend.put("dup", "b") }
  end
end
