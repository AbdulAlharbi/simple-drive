require "test_helper"

class V1::BlobsControllerTest < ActionDispatch::IntegrationTest
  AUTH = { "Authorization" => "Bearer test-token" }.freeze
  DATA = "SGVsbG8gU2ltcGxlIFN0b3JhZ2UgV29ybGQh" # "Hello Simple Storage World!"

  def store(id: "blob-1", data: DATA, headers: AUTH)
    post "/v1/blobs", params: { id: id, data: data }, as: :json, headers: headers
  end

  # -- authentication ------------------------------------------------------

  test "rejects requests without a token" do
    store(headers: {})
    assert_response :unauthorized

    get "/v1/blobs/blob-1"
    assert_response :unauthorized
  end

  test "rejects requests with a wrong token" do
    store(headers: { "Authorization" => "Bearer wrong" })
    assert_response :unauthorized
  end

  # -- storing -------------------------------------------------------------

  test "stores a blob and returns metadata" do
    store
    assert_response :created

    body = JSON.parse(response.body)
    assert_equal "blob-1", body["id"]
    assert_equal "27", body["size"]
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, body["created_at"])

    blob = Blob.find_by!(blob_id: "blob-1")
    assert_equal 27, blob.size
    assert_equal "local", blob.backend
  end

  test "rejects invalid Base64" do
    store(data: "not base64!!!")
    assert_response :bad_request
    assert_equal "data is not valid Base64", JSON.parse(response.body)["error"]
    assert_not Blob.exists?(blob_id: "blob-1")
  end

  test "rejects missing fields" do
    post "/v1/blobs", params: { id: "x" }, as: :json, headers: AUTH
    assert_response :bad_request

    post "/v1/blobs", params: { data: DATA }, as: :json, headers: AUTH
    assert_response :bad_request
  end

  test "rejects duplicate ids" do
    store
    store
    assert_response :conflict
    assert_equal 1, Blob.where(blob_id: "blob-1").count
  end

  test "accepts the empty blob" do
    store(data: "")
    assert_response :created
    assert_equal "0", JSON.parse(response.body)["size"]
  end

  # -- retrieving ----------------------------------------------------------

  test "retrieves a stored blob with data, size and created_at" do
    store
    get "/v1/blobs/blob-1", headers: AUTH
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "blob-1", body["id"]
    assert_equal DATA, body["data"]
    assert_equal "27", body["size"]
    assert_match(/Z\z/, body["created_at"])
  end

  test "supports ids that look like paths" do
    store(id: "backups/2026/app.tar.gz")
    assert_response :created

    get "/v1/blobs/backups/2026/app.tar.gz", headers: AUTH
    assert_response :success
    assert_equal "backups/2026/app.tar.gz", JSON.parse(response.body)["id"]
  end

  test "returns 404 for unknown blobs" do
    get "/v1/blobs/unknown", headers: AUTH
    assert_response :not_found
  end

  # -- backend integration -------------------------------------------------

  test "database backend stores payload in blob_contents, metadata in blobs" do
    Rails.configuration.x.storage.stub_backend("database") do
      store(id: "db-blob")
      assert_response :created
    end

    assert_equal "database", Blob.find_by!(blob_id: "db-blob").backend
    assert BlobContent.exists?(blob_id: "db-blob")

    # Retrieval uses the backend recorded on the blob, even if the
    # service has since been reconfigured to a different backend.
    get "/v1/blobs/db-blob", headers: AUTH
    assert_response :success
    assert_equal DATA, JSON.parse(response.body)["data"]
  end

  test "failed backend writes leave no orphan metadata" do
    Rails.configuration.x.storage.stub_backend("s3") do
      # S3 is unconfigured in tests -> ConfigurationError -> 500
      store(id: "doomed")
      assert_response :internal_server_error
    end
    assert_not Blob.exists?(blob_id: "doomed")
  end
end

# Small helper to swap the active backend within a block.
class ActiveSupport::OrderedOptions
  def stub_backend(name)
    original = self.backend
    self.backend = name
    yield
  ensure
    self.backend = original
  end
end
