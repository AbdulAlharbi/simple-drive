require "net/http"
require "uri"

module Storage
  # S3-compatible backend speaking the S3 REST protocol directly over
  # Net::HTTP -- no S3 client libraries involved. Requests are
  # authenticated with our own SigV4 implementation (Storage::SigV4).
  #
  # Uses path-style addressing (endpoint/bucket/key), which works with
  # AWS S3, minio, DigitalOcean Spaces and Linode Object Storage alike.
  class S3Backend < BaseBackend
    def self.from_config(cfg)
      %i[endpoint bucket access_key_id secret_access_key].each do |key|
        raise ConfigurationError, "S3 backend: missing #{key.to_s.upcase} configuration" if cfg[key].blank?
      end
      new(
        endpoint: cfg[:endpoint], bucket: cfg[:bucket], region: cfg[:region],
        access_key_id: cfg[:access_key_id], secret_access_key: cfg[:secret_access_key]
      )
    end

    def initialize(endpoint:, bucket:, region:, access_key_id:, secret_access_key:)
      @endpoint = URI(endpoint)
      @bucket = bucket
      @signer = SigV4.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        region: region || "us-east-1",
        service: "s3"
      )
    end

    def put(id, bytes)
      response = request("PUT", object_path(id), payload: bytes,
                         headers: { "content-type" => "application/octet-stream" })
      return if response.is_a?(Net::HTTPSuccess)

      raise Error, "S3 PUT failed (#{response.code}): #{response.body.to_s.truncate(500)}"
    end

    def get(id)
      response = request("GET", object_path(id))
      case response
      when Net::HTTPSuccess  then response.body.to_s.b
      when Net::HTTPNotFound then raise NotFound, "blob #{id.inspect} not found in S3 bucket"
      else raise Error, "S3 GET failed (#{response.code}): #{response.body.to_s.truncate(500)}"
      end
    end

    private

    # The blob id is opaque and may contain any character, so the object
    # key is the fully percent-encoded id ('/' included) -- always a
    # single, unambiguous path segment.
    def object_path(id)
      base = @endpoint.path.chomp("/")
      "#{base}/#{SigV4.uri_encode(@bucket)}/#{SigV4.uri_encode(id)}"
    end

    def request(method, path, payload: "", headers: {})
      host_header = if [80, 443].include?(@endpoint.port)
                      @endpoint.host
                    else
                      "#{@endpoint.host}:#{@endpoint.port}"
                    end

      signed = @signer.sign(method: method, host: host_header, path: path,
                            headers: headers, payload: payload)

      klass = method == "PUT" ? Net::HTTP::Put : Net::HTTP::Get
      req = klass.new(path)
      signed.each { |k, v| req[k] = v }
      req.body = payload if method == "PUT"

      Net::HTTP.start(@endpoint.host, @endpoint.port,
                      use_ssl: @endpoint.scheme == "https",
                      open_timeout: 10, read_timeout: 30) do |http|
        http.request(req)
      end
    rescue SystemCallError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Error, "S3 request failed: #{e.class}: #{e.message}"
    end
  end
end
