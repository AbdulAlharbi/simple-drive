require "test_helper"
require "webrick"

# Integration-style test: the backend talks real HTTP to an in-process
# fake S3 server, proving the requests are plain Net::HTTP (no SDK) and
# carry SigV4 authentication.
class S3BackendTest < ActiveSupport::TestCase
  def setup
    @objects = {}
    @requests = []
    @server = WEBrick::HTTPServer.new(
      Port: 0, BindAddress: "127.0.0.1",
      Logger: WEBrick::Log.new(File::NULL), AccessLog: [],
      DoNotReverseLookup: true
    )
    objects = @objects
    requests = @requests
    @server.mount_proc "/" do |req, res|
      requests << { method: req.request_method, path: req.path, raw_path: req.unparsed_uri, auth: req["authorization"],
                    content_sha: req["x-amz-content-sha256"], date: req["x-amz-date"] }
      case req.request_method
      when "PUT"
        objects[req.path] = req.body.to_s
        res.status = 200
      when "GET"
        if objects.key?(req.path)
          res.status = 200
          res.body = objects[req.path]
        else
          res.status = 404
          res.body = "<Error><Code>NoSuchKey</Code></Error>"
        end
      end
    end
    @thread = Thread.new { @server.start }
    @port = @server.config[:Port]

    @backend = Storage::S3Backend.new(
      endpoint: "http://127.0.0.1:#{@port}",
      bucket: "test-bucket",
      region: "us-east-1",
      access_key_id: "AKIDEXAMPLE",
      secret_access_key: "secret"
    )
  end

  def teardown
    @server.shutdown
    @thread.join(5) || @thread.kill
  end

  test "round-trips binary data over raw HTTP" do
    bytes = Random.bytes(2048)
    @backend.put("s3-id", bytes)
    assert_equal bytes, @backend.get("s3-id")
  end

  test "requests are SigV4-signed with a payload hash" do
    @backend.put("signed", "hello")
    put = @requests.find { |r| r[:method] == "PUT" }

    assert_match %r{\AAWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/\d{8}/us-east-1/s3/aws4_request, SignedHeaders=.*host.*x-amz-date.*, Signature=\h{64}\z}, put[:auth]
    assert_equal Digest::SHA256.hexdigest("hello"), put[:content_sha]
  end

  test "object keys are fully percent-encoded (ids with slashes are safe)" do
    @backend.put("docs/a b.txt", "x")
    put = @requests.find { |r| r[:method] == "PUT" }
    assert_equal "/test-bucket/docs%2Fa%20b.txt", put[:raw_path]
    assert_equal "x".b, @backend.get("docs/a b.txt")
  end

  test "maps 404 to Storage::NotFound" do
    assert_raises(Storage::NotFound) { @backend.get("missing") }
  end

  test "raises Storage::Error when the server is unreachable" do
    dead = Storage::S3Backend.new(
      endpoint: "http://127.0.0.1:1", bucket: "b", region: "us-east-1",
      access_key_id: "k", secret_access_key: "s"
    )
    assert_raises(Storage::Error) { dead.put("x", "y") }
  end

  test "from_config validates required settings" do
    assert_raises(Storage::ConfigurationError) do
      Storage::S3Backend.from_config({ endpoint: nil, bucket: "b", access_key_id: "k", secret_access_key: "s" })
    end
  end
end
